@icon("res://addons/AdvancededBoneAttachment3D/icon.svg")

@tool
extends Node3D
class_name AdvancedBoneAttachment3D

## Продвинутый BoneAttachment3D с расширенными возможностями настройки

@export_group("Skeleton Settings")
@export var skeleton: Skeleton3D : set = set_skeleton
@export var bone_name: String = "" : set = set_bone_name

@export_group("Follow Settings")
@export var follow_position: bool = true : set = set_follow_position
@export var follow_rotation: bool = true : set = set_follow_rotation

@export_group("Position Axes")
@export var follow_x_axis: bool = true : set = set_follow_x_axis
@export var follow_y_axis: bool = true : set = set_follow_y_axis
@export var follow_z_axis: bool = true : set = set_follow_z_axis

@export_group("Offset Settings")
@export var position_offset: Vector3 = Vector3.ZERO : set = set_position_offset
@export var rotation_offset: Vector3 = Vector3.ZERO : set = set_rotation_offset

@export_group("Scale Settings")

@export_group("Advanced Settings")
@export var AppendTransformToParent: bool = false
@export var auto_update: bool = true : set = set_auto_update
@export var interpolation_speed: float = 0.0 : set = set_interpolation_speed

# Внутренние переменные
var bone_idx: int = -1
var cached_bone_transform: Transform3D
var initial_transform: Transform3D
var is_ready: bool = false
var parent: Node3D

# Сигналы для уведомления об изменениях
signal skeleton_changed(new_skeleton: Skeleton3D)
signal bone_changed(new_bone_name: String)

func _ready():
	is_ready = true
	initial_transform = transform
	if skeleton:
		_update_bone_index()
	set_notify_transform(true)
	parent = get_parent()

func _process(delta):
	if not is_ready or not skeleton or bone_idx < 0 or not auto_update:
		return

	_update_attachment()

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		match what:
			NOTIFICATION_PARENTED:
				print("Новый родитель: ", get_parent().name)
				parent = get_parent()
			NOTIFICATION_UNPARENTED:
				print("Нода откреплена")
			NOTIFICATION_CHILD_ORDER_CHANGED:
				print("Порядок детей изменен")

# Setters
func set_skeleton(value: Skeleton3D):
	if skeleton == value:
		return

	if skeleton and skeleton.is_connected("skeleton_updated", _on_skeleton_updated):
		skeleton.disconnect("skeleton_updated", _on_skeleton_updated)

	skeleton = value

	if skeleton:
		skeleton.connect("skeleton_updated", _on_skeleton_updated)
		_update_bone_index()
	else:
		bone_idx = -1

	skeleton_changed.emit(skeleton)
	notify_property_list_changed()

func set_bone_name(value: String):
	if bone_name == value:
		return

	bone_name = value
	_update_bone_index()
	bone_changed.emit(bone_name)

func set_follow_position(value: bool):
	follow_position = value
	_update_attachment()

func set_follow_rotation(value: bool):
	follow_rotation = value
	_update_attachment()

func set_follow_x_axis(value: bool):
	follow_x_axis = value
	_update_attachment()

func set_follow_y_axis(value: bool):
	follow_y_axis = value
	_update_attachment()

func set_follow_z_axis(value: bool):
	follow_z_axis = value
	_update_attachment()

func set_position_offset(value: Vector3):
	position_offset = value
	_update_attachment()

func set_rotation_offset(value: Vector3):
	rotation_offset = value
	_update_attachment()

func set_auto_update(value: bool):
	auto_update = value

func set_interpolation_speed(value: float):
	interpolation_speed = max(0.0, value)

# Основная логика
func _update_bone_index():
	if not skeleton or bone_name.is_empty():
		bone_idx = -1
		return

	bone_idx = skeleton.find_bone(bone_name)
	if bone_idx >= 0:
		cached_bone_transform = skeleton.get_bone_global_pose(bone_idx)

func _update_attachment():
	if not skeleton or bone_idx < 0:
		return
	
	var current_scale = scale
	var bone_transform = skeleton.get_bone_global_pose(bone_idx)
	var target_transform = Transform3D()

	# Применяем позицию с учетом осей
	if follow_position:
		var current_pos = global_position
		var bone_pos = skeleton.global_transform * bone_transform.origin
		var target_pos = Vector3()

		target_pos.x = bone_pos.x if follow_x_axis else current_pos.x
		target_pos.y = bone_pos.y if follow_y_axis else current_pos.y
		target_pos.z = bone_pos.z if follow_z_axis else current_pos.z

		# Добавляем смещение
		var offset_global = skeleton.global_transform.basis * (bone_transform.basis * position_offset)
		target_pos += offset_global

		target_transform.origin = target_pos
	else:
		target_transform.origin = global_position

	# Применяем поворот
	if follow_rotation:
		var bone_rotation = skeleton.global_transform.basis * bone_transform.basis
		var offset_rotation = Basis.from_euler(rotation_offset)
		target_transform.basis = bone_rotation * offset_rotation
	else:
		target_transform.basis = global_transform.basis

	# Применяем трансформацию с интерполяцией или без
	if not AppendTransformToParent:
		if interpolation_speed > 0.0:
			var delta = get_process_delta_time()
			global_transform = global_transform.interpolate_with(target_transform, interpolation_speed * delta)
		else:
			global_transform = target_transform
	elif parent and parent.get_parent() != null:
		parent.global_transform = target_transform
		parent.scale = current_scale
	
	scale = current_scale
	
	cached_bone_transform = bone_transform

func _on_skeleton_updated():
	_update_attachment()

# Вспомогательные методы
func get_bone_names() -> Array[String]:
	if not skeleton:
		return []

	var names: Array[String] = []
	for i in range(skeleton.get_bone_count()):
		names.append(skeleton.get_bone_name(i))
	return names

func is_bone_valid() -> bool:
	return skeleton != null and bone_idx >= 0

func get_bone_global_transform() -> Transform3D:
	if not is_bone_valid():
		return Transform3D()
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)

func reset_to_bone_transform():
	if not is_bone_valid():
		return

	var bone_transform = get_bone_global_transform()
	global_transform = bone_transform

func force_update():
	_update_attachment()

# Методы для работы с инспектором
func _get_property_list():
	var properties = []

	# Добавляем выпадающий список для выбора кости
	if skeleton:
		var bone_names = get_bone_names()
		if bone_names.size() > 0:
			properties.append({
				"name": "bone_name",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(bone_names)
			})

	return properties

func _validate_property(property: Dictionary):
	# Скрываем bone_name если нет скелета
	if property.name == "bone_name" and not skeleton:
		property.usage = PROPERTY_USAGE_NO_EDITOR

# Отладочные методы
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()

	if not skeleton:
		warnings.append("Skeleton3D не установлен")
	elif bone_name.is_empty():
		warnings.append("Имя кости не выбрано")
	elif bone_idx < 0:
		warnings.append("Кость '%s' не найдена в скелете" % bone_name)

	if not follow_position and not follow_rotation:
		warnings.append("Не выбрано ни позиции, ни поворота для следования")

	if follow_position and not follow_x_axis and not follow_y_axis and not follow_z_axis:
		warnings.append("Включено следование позиции, но не выбрана ни одна ось")

	return warnings

func _to_string() -> String:
	return "AdvancedBoneAttachment3D(skeleton=%s, bone=%s)" % [skeleton, bone_name]
