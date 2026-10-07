extends Node
# scenes/network/online_network_manager.gd (autoload: OnlineNetworkManager)
#
# Modo Online: conecta os jogadores sem ninguém precisar abrir porta no
# roteador. Um servidor de sinalização WebSocket só troca SDP/ICE entre os
# peers; o tráfego do jogo em si vai direto peer-to-peer via WebRTC,
# atravessando NAT com a ajuda de STUN público do Google.
#
# Depois que a malha está montada, este script atribui o peer resultante a
# multiplayer.multiplayer_peer. Dali em diante o GameManager assume
# normalmente — ele escuta os sinais genéricos do MultiplayerAPI, não o
# transporte específico, então os MultiplayerSpawners e os RPCs de gameplay
# continuam funcionando sem mudança nenhuma.
#
# Adaptado de project-adventure/autoload/online_network_manager.gd, que só
# atendia 2 jogadores em estrela. Aqui a malha é completa (até MAX_PEERS) e
# quem atribui o id inteiro do Godot é o servidor — ver server/signaling.
#
# Uso:
#   OnlineNetworkManager.host_online("minha_sala")
#   OnlineNetworkManager.join_online("minha_sala")

const SIGNALING_URL := "wss://signal-server-webrtc.onrender.com"

# Permite apontar pra um servidor local durante os testes
# (ex: DUCKHUNT_SIGNALING_URL=ws://127.0.0.1:3000) sem editar a constante.
func _url() -> String:
	var env := OS.get_environment("DUCKHUNT_SIGNALING_URL")
	return env if env != "" else SIGNALING_URL

# Namespaceia o código da sala no servidor, que é compartilhado com o
# project-adventure. Sem isso, "sala1" dos dois jogos seria a mesma sala.
const APP_ID := "duckhunt"

const MAX_PEERS := 4

const ICE_SERVERS := [
	{ "urls": ["stun:stun.l.google.com:19302"] },
	{ "urls": ["stun:stun1.l.google.com:19302"] },
]

# O free tier do Render hiberna e leva 30-60s pra acordar no primeiro acesso.
const TIMEOUT_SIGNALING_MS := 45000

# Por par de peers, do add_peer() até o canal de dados abrir. Sem isso um par
# que nunca negocia falha em silêncio absoluto: WebRTCMultiplayerPeer só emite
# peer_disconnected pra peer que chegou a conectar.
const TIMEOUT_NEGOCIACAO_MS := 20000

enum Estado { OCIOSO, CONECTANDO, NA_SALA }

signal sala_criada(codigo: String)
signal sala_entrou(codigo: String)
signal falhou(motivo: String)
signal peer_negociacao_falhou(godot_id: int)
signal host_saiu()

var _socket: WebSocketPeer = null
var _estado: Estado = Estado.OCIOSO
var _codigo := ""
var _sou_host := false
var _meu_peer_id := ""          # id string do servidor de sinalização
var _meu_godot_id := 0
var _rtc: WebRTCMultiplayerPeer = null
var _conns: Dictionary = {}     # peerId (String) -> WebRTCPeerConnection
var _ids: Dictionary = {}       # peerId (String) -> id inteiro do Godot
var _peer_ids: Dictionary = {}  # id inteiro do Godot -> peerId (String)
var _prazos: Dictionary = {}    # peerId (String) -> ticks_msec limite

# ---------- Ciclo de vida ----------

func _ready() -> void:
	set_process(false)
	multiplayer.peer_connected.connect(_on_mp_peer_connected)

func _process(_delta: float) -> void:
	if _socket != null:
		_socket.poll()
		var st := _socket.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				_tratar_mensagem(_socket.get_packet().get_string_from_utf8())
		elif st == WebSocketPeer.STATE_CLOSED:
			# Com a malha montada o servidor de sinalização já é dispensável
			# (o tráfego é direto), então perder o socket aqui não derruba a
			# partida — só solta a referência.
			_socket = null
			if _estado != Estado.NA_SALA:
				_falhar("Conexão com o servidor de sinalização caiu")
				return
	_checar_prazos()
	if _socket == null and _prazos.is_empty():
		set_process(false)

func _checar_prazos() -> void:
	if _prazos.is_empty():
		return
	var agora := Time.get_ticks_msec()
	for peer_id in _prazos.keys():
		if agora <= int(_prazos[peer_id]):
			continue
		var gid := int(_ids.get(peer_id, 0))
		_prazos.erase(peer_id)
		push_warning("WebRTC: negociação com %s (godotId %d) expirou" % [peer_id, gid])
		_derrubar_peer(peer_id)
		peer_negociacao_falhou.emit(gid)

func _on_mp_peer_connected(id: int) -> void:
	# O canal de dados com esse peer abriu de verdade: cancela o prazo dele.
	if _peer_ids.has(id):
		_prazos.erase(_peer_ids[id])

# ---------- API pública ----------

func host_online(sala: String) -> void:
	if _estado != Estado.OCIOSO:
		return
	_resetar_estado()
	_codigo = sala
	_sou_host = true
	if not await _abrir_signaling():
		return
	_enviar({ "type": "create_room", "app": APP_ID, "room": sala, "maxPeers": MAX_PEERS })

func join_online(sala: String) -> void:
	if _estado != Estado.OCIOSO:
		return
	_resetar_estado()
	_codigo = sala
	_sou_host = false
	if not await _abrir_signaling():
		return
	_enviar({ "type": "join_room", "app": APP_ID, "room": sala })

# Chamado pelo host ao iniciar a partida: ninguém mais entra depois disso.
func trancar_sala() -> void:
	if _sou_host:
		_enviar({ "type": "lock_room" })
	if _rtc != null:
		_rtc.refuse_new_connections = true

func esta_online() -> bool:
	return _estado != Estado.OCIOSO

# Quantos peers já fecharam a malha comigo.
func peers_conectados() -> int:
	return multiplayer.get_peers().size() if _rtc != null else 0

func desconectar() -> void:
	for peer_id in _conns.keys():
		var c: WebRTCPeerConnection = _conns[peer_id]
		if is_instance_valid(c):
			c.close()
	_conns.clear()
	if _rtc != null:
		_rtc.close()
		_rtc = null
	if _socket != null:
		# Se eu sou o host, isso dispara host_left nos clientes — que é
		# exatamente o que se quer numa saída voluntária.
		_socket.close()
		_socket = null
	_resetar_estado()
	set_process(false)
	# Nunca deixar multiplayer_peer nulo: no Godot 4.7, uma vez que um peer
	# real foi atribuído e depois zerado, get_unique_id() passa a devolver 0
	# pra sempre. OfflineMultiplayerPeer é o mesmo objeto que o motor atribui
	# no construtor do SceneMultiplayer, então isso restaura o estado inicial.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

# ---------- Conexão com o servidor de sinalização ----------

func _resetar_estado() -> void:
	_conns.clear()
	_ids.clear()
	_peer_ids.clear()
	_prazos.clear()
	_meu_peer_id = ""
	_meu_godot_id = 0
	_codigo = ""
	_sou_host = false
	_estado = Estado.OCIOSO

func _abrir_signaling() -> bool:
	_estado = Estado.CONECTANDO
	_socket = WebSocketPeer.new()
	if _socket.connect_to_url(_url()) != OK:
		_falhar("Não foi possível abrir o servidor de sinalização")
		return false
	set_process(true)
	var limite := Time.get_ticks_msec() + TIMEOUT_SIGNALING_MS
	while _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() > limite:
			_falhar("Tempo esgotado ao conectar (o servidor pode estar hibernando)")
			return false
		await get_tree().process_frame
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_falhar("Falha ao abrir WebSocket com o servidor de sinalização")
		return false
	return true

func _enviar(data: Dictionary) -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))

func _falhar(motivo: String) -> void:
	falhou.emit(motivo)
	desconectar()

# ---------- Tratamento de mensagens do servidor ----------

func _tratar_mensagem(raw: String) -> void:
	var msg = JSON.parse_string(raw)
	if typeof(msg) != TYPE_DICTIONARY:
		return

	match str(msg.get("type", "")):
		"room_created":
			_meu_peer_id = str(msg["peerId"])
			_meu_godot_id = int(msg.get("godotId", 1))
			_registrar_a_mim()
			_montar_malha(_meu_godot_id)
			_estado = Estado.NA_SALA
			sala_criada.emit(str(msg.get("room", _codigo)))

		"joined_room":
			_meu_peer_id = str(msg["peerId"])
			# Fallback v1: servidor antigo não manda godotId/peers. Assim o
			# jogo ainda sobe (em estrela, 2 jogadores) se o deploy estiver
			# desatualizado, em vez de quebrar sem explicação.
			_meu_godot_id = int(msg.get("godotId", 2))
			_registrar_a_mim()
			_montar_malha(_meu_godot_id)
			_estado = Estado.NA_SALA

			var lista: Array = msg.get("peers", [
				{ "peerId": str(msg.get("hostPeerId", "")), "godotId": 1 }
			])
			for p in lista:
				var pid := str(p["peerId"])
				var gid := int(p["godotId"])
				if pid == "" or gid == _meu_godot_id:
					continue
				_registrar(pid, gid)
				# Quem chega tem sempre o id maior que os já presentes, então
				# o joiner oferta pra todo mundo e os presentes esperam.
				_criar_conexao(pid, _meu_godot_id > gid)
			sala_entrou.emit(str(msg.get("room", _codigo)))

		"new_peer":
			var pid := str(msg["peerId"])
			var gid := int(msg.get("godotId", 0))
			if gid <= 0 or gid == _meu_godot_id or _conns.has(pid):
				return
			_registrar(pid, gid)
			_criar_conexao(pid, _meu_godot_id > gid)

		"signal":
			_tratar_signal(str(msg["from"]), msg["data"])

		"peer_left":
			_derrubar_peer(str(msg["peerId"]))

		"host_left":
			host_saiu.emit()
			# Adiado: desmontar a malha aqui dentro é mexer no peer enquanto o
			# próprio _process ainda está consumindo pacotes.
			desconectar.call_deferred()

		"error":
			_falhar(str(msg.get("message", "Erro desconhecido")))

func _registrar_a_mim() -> void:
	_ids[_meu_peer_id] = _meu_godot_id
	_peer_ids[_meu_godot_id] = _meu_peer_id

func _registrar(peer_id: String, godot_id: int) -> void:
	_ids[peer_id] = godot_id
	_peer_ids[godot_id] = peer_id
	_prazos[peer_id] = Time.get_ticks_msec() + TIMEOUT_NEGOCIACAO_MS

# ---------- WebRTC ----------

func _montar_malha(meu_id: int) -> void:
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_mesh(meu_id)
	multiplayer.multiplayer_peer = _rtc

func _criar_conexao(peer_id: String, inicia: bool) -> void:
	var conn := WebRTCPeerConnection.new()
	if conn.initialize({ "iceServers": ICE_SERVERS }) != OK:
		push_error("WebRTC: initialize falhou para %s" % peer_id)
		return
	_conns[peer_id] = conn

	var gid: int = _ids[peer_id]

	# add_peer() já cria sozinho os canais de dados negociados que o
	# WebRTCMultiplayerPeer usa (ids 1/2/3 — reliable/ordered/unreliable), e
	# exige connection_state == STATE_NEW. Tem que vir ANTES de qualquer SDP,
	# e não se cria canal na mão aqui: um create_data_channel(id=1) antes
	# disso duplica o id 1 e o canal do add_peer() nunca abre de verdade — a
	# conexão RTC fecha (CONNECTED), mas peer_connected nunca dispara porque
	# ele exige o canal aberto.
	if _rtc.add_peer(conn, gid) != OK:
		push_error("WebRTC: add_peer(%d) falhou" % gid)
		_conns.erase(peer_id)
		return

	conn.session_description_created.connect(
		func(tipo: String, sdp: String) -> void:
			_log("session_description_created type=%s para %s" % [tipo, peer_id])
			conn.set_local_description(tipo, sdp)
			_enviar({
				"type": "signal",
				"to": peer_id,
				"data": { "sdp_type": tipo, "sdp": sdp },
			})
	)

	conn.ice_candidate_created.connect(
		func(midia: String, indice: int, nome: String) -> void:
			_enviar({
				"type": "signal",
				"to": peer_id,
				"data": { "ice_media": midia, "ice_index": indice, "ice_name": nome },
			})
	)

	if inicia:
		conn.create_offer()

func _tratar_signal(de: String, data: Dictionary) -> void:
	if not _conns.has(de):
		_log("signal de peer desconhecido %s, ignorando" % de)
		return
	var conn: WebRTCPeerConnection = _conns[de]

	if data.has("sdp_type"):
		# O WebRTCPeerConnection do Godot não tem create_answer(): entregar a
		# offer remota via set_remote_description() já gera a answer
		# internamente e dispara session_description_created pra ela.
		conn.set_remote_description(str(data["sdp_type"]), str(data["sdp"]))
	elif data.has("ice_media"):
		conn.add_ice_candidate(str(data["ice_media"]), int(data["ice_index"]), str(data["ice_name"]))

func _derrubar_peer(peer_id: String) -> void:
	if _ids.has(peer_id):
		var gid: int = _ids[peer_id]
		if _rtc != null and _rtc.has_peer(gid):
			_rtc.remove_peer(gid)
		_peer_ids.erase(gid)
		_ids.erase(peer_id)
	if _conns.has(peer_id):
		var c: WebRTCPeerConnection = _conns[peer_id]
		if is_instance_valid(c):
			c.close()
		_conns.erase(peer_id)
	_prazos.erase(peer_id)

func _log(msg: String) -> void:
	if OS.is_debug_build():
		print("[OnlineNetworkManager] ", msg)
