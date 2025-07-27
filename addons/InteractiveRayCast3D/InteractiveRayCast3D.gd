@tool
extends RayCast3D
class_name InteractiveRayCast3D

@export var UseInterpolation: bool = false
@export var LerpSpeed: float = 10.0
@export var position_offset: Vector3 = Vector3.ZERO
@export var use_surface_normal: bool = false
@export var normal_rotation_degrees: Vector3 = Vector3.ZERO
@export var normal_influence: float = 0.0
@export var TransformSpecificNode: Node3D
@export var global_rotation_offset: Vector3 = Vector3.ZERO
@export var respect_parent_rotation: bool = true  # Новая опция для учета родительского поворота

# Для стабилизации вращения
var _stable_basis: Basis = Basis.IDENTITY
var _last_normal: Vector3 = Vector3.UP

func _physics_process(delta):
	force_raycast_update()
	if is_colliding():
		var collision_point = get_collision_point()
		var final_position = collision_point + position_offset
		
		if use_surface_normal:
			var collision_normal = get_collision_normal()
			var rotated_normal = _rotate_vector(collision_normal, normal_rotation_degrees)
			final_position += rotated_normal * normal_influence
			
			if UseInterpolation:
				# Плавное изменение нормали
				_last_normal = rotated_normal
				
				# Создаем стабильное вращение с учетом родительского поворота
				var target_basis = _calculate_stable_basis(_last_normal).orthonormalized()
				_stable_basis = _stable_basis.slerp(target_basis, LerpSpeed * delta)
			else:
				_last_normal = rotated_normal
				
				# Создаем стабильное вращение с учетом родительского поворота
				var target_basis = _calculate_stable_basis(_last_normal)
				_stable_basis = target_basis

		# Применение трансформации
		_apply_transform(final_position, delta)

# Расчет стабильного базиса с учетом родительского поворота
func _calculate_stable_basis(normal: Vector3) -> Basis:
	var basis = Basis()
	
	# Основная ось (Z) вдоль нормали
	var z_axis = normal.normalized()
	
	# Если учитываем родительский поворот
	if respect_parent_rotation and TransformSpecificNode and TransformSpecificNode.get_parent() is Node3D:
		var parent_basis = TransformSpecificNode.get_parent().global_transform.basis
		
		# Преобразуем нормаль в локальное пространство родителя
		var local_z = parent_basis.inverse() * z_axis
		
		# Вспомогательная ось (X) - проекция локального "right" родителя
		var local_x = Vector3.RIGHT - local_z * local_z.dot(Vector3.RIGHT)
		if local_x.length_squared() < 0.001:
			local_x = Vector3.FORWARD - local_z * local_z.dot(Vector3.FORWARD)
		local_x = local_x.normalized()
		
		# Восстановление ортогонального базиса в локальном пространстве
		var local_y = local_z.cross(local_x).normalized()
		local_x = local_y.cross(local_z).normalized()
		
		# Преобразуем обратно в глобальное пространство
		basis.x = parent_basis * local_x
		basis.y = parent_basis * local_y
		basis.z = parent_basis * local_z
	else:
		# Старый метод без учета родительского поворота
		var x_axis = Vector3.RIGHT - z_axis * z_axis.dot(Vector3.RIGHT)
		if x_axis.length_squared() < 0.001:
			x_axis = Vector3.FORWARD - z_axis * z_axis.dot(Vector3.FORWARD)
		x_axis = x_axis.normalized()
		
		var y_axis = z_axis.cross(x_axis).normalized()
		x_axis = y_axis.cross(z_axis).normalized()
		
		basis.x = x_axis
		basis.y = y_axis
		basis.z = z_axis
	
	# Применяем глобальное вращение
	if global_rotation_offset != Vector3.ZERO:
		var rot_basis = Basis.from_euler(global_rotation_offset * PI / 180.0)
		basis = basis * rot_basis
	
	return basis

# Остальные методы без изменений
func _apply_transform(position: Vector3, delta: float):
	if TransformSpecificNode is Node3D:
		if UseInterpolation:
			TransformSpecificNode.global_position = TransformSpecificNode.global_position.lerp(position, LerpSpeed * delta)
			TransformSpecificNode.global_transform.basis = _stable_basis
		else:
			TransformSpecificNode.global_position = position
			TransformSpecificNode.global_transform.basis = _stable_basis
	
	for child in get_children():
		if UseInterpolation:
			child.global_position = child.global_position.lerp(position, LerpSpeed * delta)
			child.global_transform.basis = _stable_basis
		else:
			child.global_position = position
			child.global_transform.basis = _stable_basis

func _rotate_vector(v: Vector3, rotation_degrees: Vector3) -> Vector3:
	var rot = rotation_degrees * PI / 180.0
	var basis = Basis.from_euler(rot)
	return basis * v.normalized()
