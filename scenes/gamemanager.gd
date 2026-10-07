extends Node
# scenes/gamemanager.gd (autoload: GameManager)
#
# Estado global da partida e as três formas de entrar nela:
#   SOZINHO - offline, sem rede nenhuma
#   LOCAL   - ENet na mesma rede (host mostra o IP, quem entra digita)
#   ONLINE  - código de sala via WebRTC + servidor de sinalização, sem abrir
#             porta no roteador (ver scenes/network/online_network_manager.gd)
#
# Os três caminhos convergem no mesmo handshake de roster, porque tudo daqui
# pra frente fala só com o MultiplayerAPI genérico, não com o transporte.

enum Modo { SOZINHO, LOCAL, ONLINE }

const PORTA_LOCAL := 8910
const MAX_PLAYERS := 4
const MAX_PATOS := 2

# Variaveis Publicas
var peer
var alvo = true
var modo_multiplayer = false
var modo: Modo = Modo.SOZINHO
var players_patos = []

# Variaveis Privadas
var _player_nome
var _quantidade_patos = 0
# Uma queda gera mais de um aviso (peer_disconnected(1) e server_disconnected
# no mesmo poll, mais o host_left do signaling). Sem isto o jogador levava
# dois avisos e duas trocas de cena pela mesma desconexão.
var _encerrando := false
# Último recado, pro lobby mostrar quando ele ainda nem existia na hora.
var mensagem_pendente := ""
var _players_dicionario: Dictionary = {}
# Peers que já reportaram ter carregado a própria cópia de main.tscn (e
# portanto os próprios MultiplayerSpawners). Um spawn enviado a um peer cujo
# spawner ainda não existe é simplesmente descartado, e nada reenvia depois.
var _peers_prontos: Dictionary = {}

# Sinais
signal player_desconectou(player_id)
signal roster_atualizado(dicionario)
signal conexao_falhou(motivo)
signal sala_online_criada(codigo)
signal todos_prontos()
# Recado pro jogador, mostrado na StatusLabel do lobby. Substitui o OS.alert:
# um diálogo modal disparado de dentro de um callback de rede travava a thread
# principal no meio da desconexão, inclusive antes da troca de cena.
signal aviso(texto)

func _ready() -> void:
	# Todas as ligações de sinal ficam AQUI, uma única vez. Fazer isso dentro
	# de create_server/join_server (como era antes) empilhava uma conexão nova
	# a cada entrar->desconectar->entrar: o handshake disparava duas vezes e o
	# segundo remove_player quebrava numa chave já apagada.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)

	OnlineNetworkManager.host_saiu.connect(_on_server_disconnected)
	OnlineNetworkManager.falhou.connect(_on_online_falhou)
	OnlineNetworkManager.sala_criada.connect(_on_sala_online_criada)
	OnlineNetworkManager.peer_negociacao_falhou.connect(_on_negociacao_falhou)

func get_nome(_unique_id) -> String:
	if not _players_dicionario.has(str(_unique_id)):
		return ""
	return _players_dicionario[str(_unique_id)]["nome"]

# ---------- Entradas dos três modos ----------

# Fecha o que estiver aberto e zera o estado. Toda entrada de modo começa
# por aqui, senão um peer da sessão anterior fica aberto e atribuído.
func _preparar_nova_sessao() -> void:
	_encerrar_rede()
	_reset()
	_encerrando = false

func jogar_sozinho(_nome) -> void:
	_preparar_nova_sessao()
	modo = Modo.SOZINHO
	modo_multiplayer = false
	alvo = true
	_player_nome = _nome

func hospedar_local(_nome) -> void:
	_preparar_nova_sessao()
	modo = Modo.LOCAL
	modo_multiplayer = true
	alvo = true
	_player_nome = _nome
	var _novo := ENetMultiplayerPeer.new()
	# Bind padrão ("*", todas as interfaces). Antes isto usava o texto do
	# campo de IP, que com o default 127.0.0.1 prendia o servidor no loopback
	# e impedia qualquer peer da LAN de chegar.
	var err := _novo.create_server(PORTA_LOCAL, MAX_PLAYERS - 1)
	if err != OK:
		conexao_falhou.emit("Falha ao hospedar na porta %d (erro %d)" % [PORTA_LOCAL, err])
		return
	peer = _novo
	multiplayer.multiplayer_peer = peer
	_registrar_host()

func entrar_local(_ip, _alvo, _nome) -> void:
	_preparar_nova_sessao()
	modo = Modo.LOCAL
	modo_multiplayer = true
	alvo = _alvo
	_player_nome = _nome
	var _novo := ENetMultiplayerPeer.new()
	var err := _novo.create_client(_ip, PORTA_LOCAL)
	if err != OK:
		conexao_falhou.emit("Falha ao conectar em %s:%d (erro %d)" % [_ip, PORTA_LOCAL, err])
		return
	peer = _novo
	multiplayer.multiplayer_peer = peer

func hospedar_online(_sala, _nome) -> void:
	_preparar_nova_sessao()
	modo = Modo.ONLINE
	modo_multiplayer = true
	alvo = true
	_player_nome = _nome
	OnlineNetworkManager.host_online(_sala)

func entrar_online(_sala, _alvo, _nome) -> void:
	_preparar_nova_sessao()
	modo = Modo.ONLINE
	modo_multiplayer = true
	alvo = _alvo
	_player_nome = _nome
	OnlineNetworkManager.join_online(_sala)

# IP da LAN pra mostrar pro outro jogador digitar.
func ip_local() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

# ---------- Handshake do roster ----------

func _on_peer_connected(_id: int) -> void:
	if _id == 1 and not multiplayer.is_server():
		# Gatilho único do handshake, idêntico em ENet e WebRTC: no ENet
		# chega quando o cliente conecta no servidor; na malha WebRTC, quando
		# o canal de dados com o peer 1 abre de verdade.
		set_player_name.rpc_id(1, _player_nome, alvo)

func _on_peer_disconnected(_id: int) -> void:
	if _id == 1 and not multiplayer.is_server():
		# Host caiu. Em malha WebRTC este é o único aviso que chega —
		# server_disconnected nunca dispara nesse transporte.
		_on_server_disconnected()
		return
	if multiplayer.is_server():
		remove_player(_id)

# Só o host mexe no roster autoritativo.
func _registrar_host() -> void:
	_gera_dicionario_player(multiplayer.get_unique_id(), _player_nome, "true")
	_update_players_dicionario.rpc(_players_dicionario)

func _gera_dicionario_player(_id, _nome, _alvo):
	_players_dicionario[str(_id)] = {"nome": _nome, "alvo": _alvo}

@rpc("any_peer", "reliable")
func set_player_name(_player_name: String, _alvo: bool):
	if not multiplayer.is_server():
		return
	var _id := multiplayer.get_remote_sender_id()
	if !_alvo:
		if _quantidade_patos >= MAX_PATOS:
			_gera_dicionario_player(_id, _player_name, "true")
			_muda_para_alvo.rpc_id(_id)
			_update_players_dicionario.rpc(_players_dicionario)
			return
		_quantidade_patos += 1
		_gera_dicionario_player(_id, _player_name, "false")
		_update_players_dicionario.rpc(_players_dicionario)
	else:
		_gera_dicionario_player(_id, _player_name, "true")
		_update_players_dicionario.rpc(_players_dicionario)

@rpc("any_peer", "reliable")
func _muda_para_alvo():
	_avisar("Limite de patos atingido — você entrou como ALVO.")
	alvo = true

@rpc("any_peer", "call_local", "reliable")
func _update_players_dicionario(_players_dicionario_novo):
	self._players_dicionario = _players_dicionario_novo
	roster_atualizado.emit(_players_dicionario_novo)

func get_nome_jogavel(_alvo) -> String:
	if _alvo == "true":
		return "ALVO"
	return "PATO"

func total_jogadores() -> int:
	return _players_dicionario.size()

func remove_player(_id = 1):
	if not _players_dicionario.has(str(_id)):
		return
	player_desconectou.emit(_id)

	# O valor é a string "true"/"false", e toda string não-vazia é truthy em
	# GDScript — comparar direto decrementava o contador pra qualquer saída,
	# inclusive de ALVO.
	if _players_dicionario[str(_id)]["alvo"] == "false":
		_quantidade_patos -= 1

	_players_dicionario.erase(str(_id))
	_peers_prontos.erase(_id)

	# find() devolve -1 pra quem é ALVO; remove_at(-1) tirava o último pato.
	var _i = players_patos.find(str(_id))
	if _i != -1:
		players_patos.remove_at(_i)

	_update_players_dicionario.rpc(_players_dicionario)

# ---------- Sincronização da entrada no jogo ----------

# Cada peer avisa, junto com o papel que escolheu, quando o _ready() de
# main.tscn rodou. O host segura os spawns até todo mundo ter avisado: um
# spawn enviado a um peer cujo MultiplayerSpawner ainda não existe é
# descartado em silêncio, e nada reenvia depois.
#
# Isso mora aqui, e não em main.gd, de propósito: o caminho de um autoload
# resolve em todo peer o tempo todo, então o aviso não se perde só porque
# quem recebe ainda não trocou de cena.
@rpc("any_peer", "call_local", "reliable")
func notificar_pronto(_id: int, _e_alvo: bool) -> void:
	if not multiplayer.is_server():
		return
	_peers_prontos[_id] = _e_alvo
	if not _e_alvo and not players_patos.has(str(_id)):
		players_patos.append(str(_id))
	if todos_peers_prontos():
		_anunciar_todos_prontos.rpc()

# O host avisa a sala inteira que todo mundo carregou a cena. Os clientes
# precisam saber disso pra liberar o botão de começar a partida.
@rpc("authority", "call_local", "reliable")
func _anunciar_todos_prontos() -> void:
	todos_prontos.emit()

func todos_peers_prontos() -> bool:
	if modo == Modo.SOZINHO:
		return true
	return _peers_prontos.size() >= _players_dicionario.size()

func peers_prontos_ids() -> Array:
	return _peers_prontos.keys()

func peer_e_alvo(_id: int) -> bool:
	return bool(_peers_prontos.get(_id, true))

# ---------- Desconexão e limpeza ----------

func _avisar(texto: String) -> void:
	mensagem_pendente = texto
	aviso.emit(texto)

# Saída voluntária: sem alerta e sem troca de cena (quem chamou já está no lobby).
func on_desconected() -> void:
	if _encerrando:
		return
	_encerrando = true
	_encerrar_rede()
	_reset()

# O host sumiu. No modo Local isso chega por server_disconnected; na malha
# WebRTC esse sinal nunca dispara, e o aviso vem de peer_disconnected(1) ou do
# host_left do servidor de sinalização.
func _on_server_disconnected() -> void:
	if _encerrando:
		return
	_encerrando = true
	_avisar("Perdeu a conexão com o servidor.")
	# Adiado de propósito: este callback roda dentro do poll do MultiplayerAPI,
	# que ainda está iterando os próprios nós de replicação. Fechar o peer ou
	# liberar a cena aqui derruba o processo (SIGSEGV).
	_voltar_pro_lobby.call_deferred()

func _voltar_pro_lobby() -> void:
	_encerrar_rede()
	_reset()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _on_connection_failed() -> void:
	if _encerrando:
		return
	_encerrando = true
	_encerrar_sessao.call_deferred()
	conexao_falhou.emit("Não foi possível conectar ao host")

# Mesmo motivo do _voltar_pro_lobby: nunca mexer no peer dentro de um
# callback do MultiplayerAPI.
func _encerrar_sessao() -> void:
	_encerrar_rede()
	_reset()

func _on_online_falhou(_motivo: String) -> void:
	if _encerrando:
		return
	_encerrando = true
	_reset()
	conexao_falhou.emit(_motivo)

func _on_sala_online_criada(_codigo: String) -> void:
	# Só agora multiplayer.get_unique_id() vale alguma coisa no modo Online.
	_registrar_host()
	sala_online_criada.emit(_codigo)

func _on_negociacao_falhou(_godot_id: int) -> void:
	if multiplayer.is_server():
		remove_player(_godot_id)
		return
	# Não consegui fechar a malha com alguém: entrar assim daria um jogo em
	# que parte dos jogadores simplesmente não se vê.
	if _encerrando:
		return
	_encerrando = true
	_encerrar_sessao.call_deferred()
	conexao_falhou.emit("Não foi possível conectar com todos os jogadores")

# Único ponto do projeto que mexe em multiplayer.multiplayer_peer na saída.
func _encerrar_rede() -> void:
	if modo == Modo.ONLINE:
		OnlineNetworkManager.desconectar()  # já restaura o OfflineMultiplayerPeer
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	_restaurar_peer_offline()

# No Godot 4.7, um peer fechado continua atribuído e com unique_id 0 — a
# partir daí is_server() é falso, todo guard de servidor morre e os RPCs são
# recusados por status. OfflineMultiplayerPeer é o mesmo objeto que o motor
# atribui no construtor do SceneMultiplayer.
func _restaurar_peer_offline() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _reset():
	modo = Modo.SOZINHO
	modo_multiplayer = false
	peer = null
	alvo = true
	_players_dicionario = {}
	_peers_prontos = {}
	_player_nome = null
	players_patos = []
	_quantidade_patos = 0
