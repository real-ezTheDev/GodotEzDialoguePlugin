extends VBoxContainer

@export var dialogue: JSON

@onready var dialogue_choice_res = preload("res://crpg_dialogue_demo/DialogueButton.tscn")

var state: Dictionary = {}
var dialogue_finished = false
var is_rolling = false

var button_cache: Array[DialogueButton] = []

@onready var dialogue_handler: EzDialogue = $EzDialogue
@onready var roll_handler = $"../RollBox"

func _ready():
	dialogue_finished = false
	dialogue_handler.start_dialogue(dialogue, state)

func clear_dialogue():
	$text.text = ""
	is_rolling = false
	for child in get_children():
		if child is Button:
			child.hide()

func add_text(text: String):
	$text.text = text

func add_choice(choice_text: String, id: int):
	if button_cache.size() < id + 1:
		var new_button = dialogue_choice_res.instantiate()
		new_button.choice_id = id
		button_cache.push_back(new_button)
		add_child(new_button)
		new_button.dialogue_selected.connect(_on_choice_button_down)

	var button = button_cache[id]
	button.text = choice_text
	button.show()

func _on_choice_button_down(choice_id: int):
	clear_dialogue()
	if !dialogue_finished:
		dialogue_handler.next(choice_id)

func _on_ez_dialogue_dialogue_generated(response: DialogueResponse):
	if is_rolling:
		return

	add_text(response.text)
	if response.choices.is_empty():
		add_choice("[...]", 0)
	else:
		for i in response.choices.size():
			add_choice(response.choices[i], i)

func _on_ez_dialogue_end_of_dialogue_reached():
	dialogue_finished = true

func _on_ez_dialogue_custom_signal_received(value: String):
	var params = value.split(",")
	if params[0] == "roll":
		var category: String = params[1]
		var dc: int = int(params[2])
		roll_handler.roll(category, dc)
		is_rolling = true

func _on_roll_box_roll_finished(roll_result):
	if is_rolling:
		is_rolling = false
		state["roll"] = roll_result

	dialogue_handler.next()

