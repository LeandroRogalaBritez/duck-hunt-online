extends Control
# scenes/lobby/lobby.gd
#
# Três modos de entrar na partida (ver scenes/gamemanager.gd):
#   Sozinho - vai direto pro jogo, sem rede
#   Local   - ENet na mesma rede; o host mostra o próprio IP na tela
#   Online  - código de sala via servidor de sinalização, sem abrir porta
#
# Só o host vê o botão Iniciar, e ele só habilita quando todo mundo já fechou
# a conexão com todo mundo — entrar com a malha incompleta daria um jogo em
# que parte dos jogadores simplesmente não se vê.

const PAPEL_ALVO := 0
const PAPEL_PATO := 1

@onready var _nome: LineEdit = $Panel/Margin/Colunas/Esquerda/LineEditNome
@onready var _papel: OptionButton = $Panel/Margin/Colunas/Esquerda/OptionPapel
@onready var _sozinho: Button = $Panel/Margin/Colunas/Esquerda/Sozinho
@onready var _hospedar_local: Button = $Panel/Margin/Colunas/Esquerda/HospedarLocal
@onready var _entrar_local: Button = $Panel/Margin/Colunas/Esquerda/EntrarLocal
@onready var _ip: LineEdit = $Panel/Margin/Colunas/Esquerda/LineEditIp
@onready var _conectar_local: Button = $Panel/Margin/Colunas/Esquerda/ConectarLocal
@onready var _hospedar_online: Button = $Panel/Margin/Colunas/Esquerda/HospedarOnline
@onready var _entrar_online: Button = $Panel/Margin/Colunas/Esquerda/EntrarOnline
@onready var _sala: LineEdit = $Panel/Margin/Colunas/Esquerda/LineEditSala
@onready var _confirmar_online: Button = $Panel/Margin/Colunas/Esquerda/ConfirmarOnline
@onready var _player_list: ItemList = $Panel/Margin/Colunas/Direita/PlayerList
@onready var _status: Label = $Panel/Margin/Colunas/Direita/StatusLabel
@onready var _iniciar: Button = $Panel/Margin/Colunas/Direita/Acoes/Iniciar
@onready var _desconectar: Button = $Panel/Margin/Colunas/Direita/Acoes/Desconectar

# "host" ou "join": a qual ação o par LineEditSala/ConfirmarOnline se refere.
var _acao_online := ""

func _ready() -> void:
	_papel.clear()
	_papel.add_item("ALVO", PAPEL_ALVO)
	_papel.add_item("PATO", PAPEL_PATO)
	_papel.selected = PAPEL_ALVO

	GameManager.roster_atualizado.connect(_on_roster_atualizado)
	GameManager.conexao_falhou.connect(_on_conexao_falhou)
	GameManager.sala_online_criada.connect(_on_sala_online_criada)
	GameManager.aviso.connect(_on_aviso)
	multiplayer.peer_connected.connect(_on_peer_mudou)
	multiplayer.peer_disconnected.connect(_on_peer_mudou)

	_modo_lobby(false)
	# Recado deixado por uma sessão anterior (ex: o host caiu e nos trouxe de
	# volta pra cá) — este nó nem existia quando ele foi emitido.
	_status.text = GameManager.mensagem_pendente
	GameManager.mensagem_pendente = ""

# ---------- Sozinho ----------

func _on_sozinho_pressed() -> void:
	GameManager.jogar_sozinho(_nome.text)
	_start_game()

# ---------- Local ----------

func _on_hospedar_local_pressed() -> void:
	GameManager.hospedar_local(_nome.text)
	if GameManager.peer == null:
		return
	_status.text = "Hospedando em %s:%d\nAguardando jogadores..." % [
		GameManager.ip_local(), GameManager.PORTA_LOCAL
	]
	_modo_lobby(true)

func _on_entrar_local_pressed() -> void:
	_ip.visible = true
	_conectar_local.visible = true

func _on_conectar_local_pressed() -> void:
	var _endereco := _ip.text.strip_edges()
	if _endereco == "":
		_status.text = "Digite o IP do host."
		return
	GameManager.entrar_local(_endereco, _papel_e_alvo(), _nome.text)
	if GameManager.peer == null:
		return
	_status.text = "Conectando em %s:%d..." % [_endereco, GameManager.PORTA_LOCAL]
	_modo_lobby(true)

# ---------- Online ----------

func _on_hospedar_online_pressed() -> void:
	_acao_online = "host"
	_sala.visible = true
	_confirmar_online.visible = true
	_confirmar_online.text = "Hospedar"

func _on_entrar_online_pressed() -> void:
	_acao_online = "join"
	_sala.visible = true
	_confirmar_online.visible = true
	_confirmar_online.text = "Conectar"

func _on_confirmar_online_pressed() -> void:
	var _codigo := _sala.text.strip_edges()
	if _codigo == "":
		_status.text = "Digite o código da sala."
		return
	if _acao_online == "host":
		_status.text = "Criando sala '%s'...\n(o servidor pode levar até 1 min pra acordar)" % _codigo
		GameManager.hospedar_online(_codigo, _nome.text)
	else:
		_status.text = "Entrando na sala '%s'...\n(o servidor pode levar até 1 min pra acordar)" % _codigo
		GameManager.entrar_online(_codigo, _papel_e_alvo(), _nome.text)
	_modo_lobby(true)

func _on_sala_online_criada(_codigo: String) -> void:
	_status.text = "Sala '%s' criada.\nPasse esse código pros outros jogadores." % _codigo
	_atualiza_iniciar()

# ---------- Estado do lobby ----------

func _papel_e_alvo() -> bool:
	return _papel.selected == PAPEL_ALVO

# Alterna entre "escolhendo o modo" e "dentro de uma sala".
func _modo_lobby(_na_sala: bool) -> void:
	for _b in [_sozinho, _hospedar_local, _entrar_local, _hospedar_online, _entrar_online]:
		_b.visible = not _na_sala
	if _na_sala:
		_ip.visible = false
		_conectar_local.visible = false
		_sala.visible = false
		_confirmar_online.visible = false
	_nome.editable = not _na_sala
	_papel.disabled = _na_sala
	_desconectar.visible = _na_sala
	_atualiza_iniciar()

func _on_roster_atualizado(_dicionario) -> void:
	_player_list.clear()
	for _p in _dicionario:
		var _json = _dicionario[_p]
		_player_list.add_item(
			"%s - %s" % [_json["nome"], GameManager.get_nome_jogavel(_json["alvo"])],
			null, false
		)
	_atualiza_iniciar()

func _on_peer_mudou(_id: int) -> void:
	_atualiza_iniciar()

# Só o host inicia, e só com a malha completa: cada jogador precisa enxergar
# todos os outros. Numa malha WebRTC um par pode falhar sozinho (NAT), e aí
# esses dois nunca se veriam dentro do jogo.
func _atualiza_iniciar() -> void:
	if not GameManager.modo_multiplayer or not multiplayer.is_server():
		_iniciar.visible = false
		return
	_iniciar.visible = true
	var _total := GameManager.total_jogadores()
	var _malha_completa := multiplayer.get_peers().size() == maxi(_total - 1, 0)
	_iniciar.disabled = _total < 2 or not _malha_completa
	if _total < 2:
		_iniciar.tooltip_text = "Esperando outro jogador."
	elif not _malha_completa:
		_iniciar.tooltip_text = "Conectando todos os jogadores entre si..."
	else:
		_iniciar.tooltip_text = ""

func _on_aviso(_texto: String) -> void:
	_status.text = _texto

func _on_conexao_falhou(_motivo) -> void:
	_status.text = str(_motivo)
	_player_list.clear()
	_modo_lobby(false)

func _on_desconectar_pressed() -> void:
	GameManager.on_desconected()
	_player_list.clear()
	_status.text = ""
	_modo_lobby(false)

func _on_fechar_pressed() -> void:
	get_tree().quit()

# ---------- Início da partida ----------

func _on_iniciar_pressed() -> void:
	if GameManager.modo == GameManager.Modo.ONLINE:
		# Ninguém mais entra depois que a partida começou: um peer que
		# chegasse agora nasceria sem os spawns já feitos.
		OnlineNetworkManager.trancar_sala()
	_start_game.rpc()

@rpc("any_peer", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
