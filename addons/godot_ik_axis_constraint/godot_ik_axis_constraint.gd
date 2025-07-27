@tool  
class_name AxisConstrainedBoneConstraint extends GodotIKConstraint  
  
@export var active: bool = true  
@export var constrained_axis: Vector3 = Vector3.UP  # Ось ограничения  
@export var forward: bool = true  
@export var backward: bool = true  
@export_category("Advanceded")
@export var ChainCorrectLength: Vector3 = Vector3.ZERO
  
func apply(  
	pos_parent_bone: Vector3,  
	pos_bone: Vector3,   
	pos_child_bone: Vector3,  
	chain_dir: int  
) -> PackedVector3Array:  
	var result = [pos_parent_bone, pos_bone, pos_child_bone]  
	  
	if not active:  
		return result  
	  
	# Получаем исходную позицию кости из скелета  
	var original_pos = get_skeleton().get_bone_global_pose(bone_idx).origin  
	var effector = get_parent()

	# Проецируем движение только на заданную ось  
	var movement = pos_bone 
	var projected_movement = movement.project(constrained_axis.normalized())  
	# Применяем только проецированное движение  
	var origpos_proj = original_pos.project(constrained_axis.normalized())
	var effector_proj = effector.position.project(constrained_axis.normalized())
	#print(origpos_proj)
	#print("--- ", effector_proj)
	if true or origpos_proj < effector_proj:
		result[1] = original_pos + projected_movement + ChainCorrectLength
	return result
