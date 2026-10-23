extends Control


@onready var sens: HSlider = $Panel/VBox/SensSlider
@onready var master_vol: HSlider = $Panel/VBox/MasterSlider
@onready var sfx_vol: HSlider = $Panel/VBox/SfxSlider
@onready var fullscreen: CheckButton = $Panel/VBox/Fullscreen
@onready var bob: CheckButton = $Panel/VBox/Bob
@onready var flicker: CheckButton = $Panel/VBox/Flicker


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_from_settings()
	sens.value_changed.connect(func(v): SettingsManager.set_mouse_sensitivity(v))
	master_vol.value_changed.connect(func(v): SettingsManager.set_master_volume(v))
	sfx_vol.value_changed.connect(func(v): SettingsManager.set_sfx_volume(v))
	fullscreen.toggled.connect(func(v): SettingsManager.set_fullscreen(v))
	bob.toggled.connect(func(v): SettingsManager.set_camera_bob(v))
	flicker.toggled.connect(func(v): SettingsManager.set_flicker(v))


func _sync_from_settings() -> void:
	sens.value = SettingsManager.mouse_sensitivity
	master_vol.value = SettingsManager.master_volume
	sfx_vol.value = SettingsManager.sfx_volume
	fullscreen.button_pressed = SettingsManager.fullscreen
	bob.button_pressed = SettingsManager.camera_bob_enabled
	flicker.button_pressed = SettingsManager.flicker_enabled
