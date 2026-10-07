extends Node

const SCENE := preload("res://scenes/invasion/invasion_match.tscn")
const Controller = preload("res://scenes/invasion/invasion_match.gd")
const Actor = preload("res://scenes/invasion/alien_actor.gd")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
		push_error(description)


func _fixture() -> Controller:
	GameManager.jogar_sozinho('TESTE')
	var game := SCENE.instantiate() as Controller
	get_tree().root.add_child(game)
	game.set_physics_process(false)
	return game


func _begin(game: Controller) -> void:
	game.begin_session()
	game.step(0.81)
	_expect(game.get_status()["phase"] == Controller.Phase.DEFENSE, "Briefing must enter active defense")


func _run() -> void:
	var game := _fixture()
	_begin(game)
	_expect(not game.request_shot(Vector2(10, 50)), "HUD clicks cannot spend charges")
	_expect(game.request_shot(Vector2(350, 300)), "First active shot is accepted")
	_expect(not game.request_shot(Vector2(350, 300)), "Cooldown rejects repeated shot")
	_expect(game.get_status()["charges"] == 2, "A click spends exactly one charge")
	game.free()

	game = _fixture()
	_begin(game)
	var first := game.get_node("Aliens").get_child(0) as Actor
	var second := game.get_node("Aliens").get_child(1) as Actor
	first.speed = 0
	second.speed = 0
	second.position = first.position
	game.request_shot(first.position)
	game.step(0.16)
	_expect(game.get_status()["captures"] == 1, "A pulse captures one overlapping alien, not both")
	game.step(0.61)
	game.request_shot(second.position)
	game.step(0.16)
	_expect(game.get_status()["captures"] == 2, "Second committed pulse captures remaining alien")
	_expect(game.get_status()["score"] == 1250, "Two captures plus perfect-wave bonus are awarded once")
	_expect(game.get_status()["defense_wins"] == 1, "Perfect wave is one defense victory")
	_expect(not game.request_shot(Vector2(350, 300)), "Result presentation rejects gameplay shots")
	game.step(0.1)
	_expect(game.get_status()["score"] == 1250, "Presentation cannot award duplicate points")
	game.free()

	game = _fixture()
	_begin(game)
	first = game.get_node("Aliens").get_child(0) as Actor
	first.speed = 0
	var locked_point := first.position
	game.request_shot(locked_point)
	first.position += Vector2(100, 0)
	game.step(0.16)
	_expect(game.get_status()["captures"] == 0, "Moving outside a telegraphed point evades the committed pulse")
	game.free()

	game = _fixture()
	_begin(game)
	for i in 3:
		game.request_shot(Vector2(50, 500))
		game.step(0.61)
	_expect(game.get_status()["charges"] == 0, "Three shots exhaust the budget")
	_expect(not game.request_shot(Vector2(50, 500)), "Empty weapon cannot fire")
	_expect(game.get_status()["charges"] == 0, "Budget never becomes negative")
	_expect(game.get_status()["phase"] == Controller.Phase.LANDING, "Exhausted budget advances landing after final pulse resolves")
	game.free()

	game = _fixture()
	_begin(game)
	for i in 5:
		game.step(14.1)
		_expect(game.get_status()["phase"] == Controller.Phase.LANDING, "Countdown opens the landing corridor")
		game.step(1.21)
		_expect(game.get_status()["infiltrations"] == 2, "Both uncaptured aliens establish a landing")
		game.step(2.41)
		if i < 4:
			game.step(0.81)
	_expect(game.get_status()["phase"] == Controller.Phase.REPORT, "Five waves produce the session report")
	_expect(game.get_status()["invasion_wins"] == 5, "Each failed wave is counted once")
	game.free()

	game = _fixture()
	game.select_role(Controller.Role.ET)
	_begin(game)
	first = game.get_node("Aliens").get_child(0) as Actor
	_expect(first.human_controlled, "ET mode assigns human movement to the marked alien")
	var start := first.position
	first.buffer_dash()
	game.step(0.02, Vector2.RIGHT)
	_expect(first.position.x > start.x, "Buffered directional dash moves the human ET")
	_expect(first.dash_cooldown > 1.9, "Dash has a visible two-second cooldown")
	game.step(1.7, Vector2.LEFT)
	_expect(game.get_status()["charges"] < 3, "ET mode has an AI agent that commits pulses")
	game.select_role(Controller.Role.AGENT)
	_expect(game.get_status()["phase"] == Controller.Phase.READY, "Switching role clears the old session safely")
	_expect(game.get_status()["pending_pulses"] == 0, "Role changes discard pending pulses")
	game.free()

	var visual := OS.get_cmdline_user_args().has("--visual")
	if visual:
		game = _fixture()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://docs/invasion_ready.png")
		_begin(game)
		game.step(0.7)
		game.request_shot((game.get_node("Aliens").get_child(0) as Actor).position)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://docs/invasion_gameplay.png")
		game.begin_session()
		game.step(0.81)
		for actor: Actor in game.get_node("Aliens").get_children():
			actor.speed = 0
			game.request_shot(actor.position)
			game.step(0.16)
			game.step(0.61)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://docs/invasion_capture.png")
		game.select_role(Controller.Role.ET)
		_begin(game)
		game.step(0.2)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://docs/invasion_et.png")
		game.free()
		var lobby := load("res://scenes/lobby/lobby.tscn").instantiate() as Control
		get_tree().root.add_child(lobby)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://docs/invasion_lobby.png")
		lobby.free()
	# Let the audio server release stopped playbacks before tearing down the tree.
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: invasion input, captures, evasion, budgets, landing, session and ET dash/AI")
	get_tree().quit(0 if _failures.is_empty() else 1)
