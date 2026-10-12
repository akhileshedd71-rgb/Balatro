extends SceneTree
## Visual QA: invoke with a rendering driver, e.g. DISPLAY=:98 tools/run.sh --script res://tests/capture_screens.gd.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.run.save_path = "user://visual_test_run.json"
	game.run.new_run("MIDNIGHT")
	game.run.start_blind()
	await create_timer(1.5).timeout
	await _capture("desktop")
	game.table._select_card(3)
	game.table._select_card(4)
	await create_timer(0.3).timeout
	await _capture("selected")
	game._show_menu()
	await create_timer(0.25).timeout
	await _capture("menu")
	game.dialog.close()
	root.size = Vector2i(720, 1280)
	await create_timer(0.7).timeout
	await _capture("portrait")
	root.size = Vector2i(844, 390)
	await create_timer(0.7).timeout
	await _capture("phone_landscape")
	game._show_menu()
	await create_timer(0.3).timeout
	await _capture("phone_menu")
	game.dialog.close()
	root.size = Vector2i(1440, 900)
	await create_timer(0.3).timeout
	game.table.reduced_motion = true
	await game._play([3, 4])
	await game._play([1, 7])
	await create_timer(0.4).timeout
	await _capture("shop")
	root.size = Vector2i(844, 390)
	await create_timer(0.5).timeout
	await _capture("phone_shop")
	game.queue_free()
	await create_timer(0.2).timeout
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("/tmp/balatro_" + label + ".png")
	print("Captured ", label, " ", image.get_size())
