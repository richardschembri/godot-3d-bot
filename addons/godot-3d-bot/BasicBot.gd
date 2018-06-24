extends RigidBody

export(float) var max_speed = 0.1
export(float) var acceleration = 0.1
export(float) var max_strafe_speed = 0.25
export(float) var strafe_acceleration = 0.1
export(float) var turn_speed = 0.2

var current_speed = 0;
var current_strafe_speed = 0;
# class member variables go here, for example:
# var a = 2
# var b = "textvar"
enum ACTION_STATE{
  SLEEP,
  ADVANCE,
  TURN,
  WAIT
}
export(NodePath) var target_node_path
export(NodePath) var navigation_node_path

var target = null
var navigation = null
var self_pos = Vector3()
const UP=Vector3(0,1,0)
var path = []
var path_endpoint = Vector3()
var nav_path_endpoint = Vector3()

# Godot Methods
func _ready():
	set_target(target_node_path)
	set_navigation(navigation_node_path)
	set_path()

func _process(delta):
	pass
	
func _physics_process(delta):
	self_pos = self.get_global_transform().origin
	track_target()
	track_path()
	move_to_target()
	
func track_target():
	if (target==null):
		return
	var target_origin = target.get_global_transform().origin
	var track_pos =  Vector3(target_origin[0], get_translation()[1], target_origin[2]) # current_target_ref.get_global_transform().origin
	if $target_tracker.get_global_transform().origin != track_pos:
		var tracker_transform = $target_tracker.get_global_transform().looking_at(track_pos, UP)
		$target_tracker.set_global_transform(tracker_transform)

func track_path():
	if path.size() > 0:
		track_path_point(path[0])

func track_path_point(point):
	var point_pos =  Vector3(point.x, get_translation().y, point.z)
	if ($path_tracker.get_global_transform().origin != point_pos):
		var tracker_transform = $path_tracker.get_global_transform().looking_at(point_pos, UP)  
		$path_tracker.set_global_transform(tracker_transform)

func turn(right = true):
	if right:
		turn_by(self.turn_speed)
	else:
		turn_by(-self.turn_speed)

func turn_by(turn_radians):
	self.rotate_y(turn_radians)

#func turn_to_target():
#	if target == null:
#		return
#	var tt_rotation = $target_tracker.get_rotation()
#	if tt_rotation.y < -0.1:
#		turn(false)
#	elif tt_rotation.y > 0.1:
#		turn()
#	elif tt_rotation.y > -0.1 and tt_rotation.y < 0.1: 
#		var target_origin = target.get_global_transform().origin
#		face_point(target_origin)

func turn_to_target():
	if not turn_to_tracker($target_tracker) && target != null: 
		var target_origin = target.get_global_transform().origin
		face_point(target_origin)


func turn_to_path():
	if not turn_to_tracker($path_tracker) && path.size() > 0:
		face_point(path[0])

func turn_to_tracker(tracker):
	var tt_rotation = tracker.get_rotation()
	if tt_rotation.y < -0.1:
		turn(false)
		return true # is turning
	elif tt_rotation.y > 0.1:
		turn() 
		return true # is turning
	return false # is not turning

func face_point(point):
	var track_pos = Vector3(point.x, get_translation()[1], point.z) 
	var self_transform = get_global_transform().looking_at(track_pos, UP)
	set_global_transform(self_transform)

func set_path():
	if navigation != null:
		path_endpoint = target.get_global_transform().origin
		nav_path_endpoint = navigation.get_closest_point(path_endpoint)
		path = Array(navigation.get_simple_path(self_pos, nav_path_endpoint, true))
		if path.size() > 1:
			path.remove(0) # remove self_pos
	elif target != null:
		path = [target.get_global_transform().origin]

func advance_to_target():
	if self_pos.distance_to(target.get_global_transform().origin) > abs($ray_proximity_front.cast_to.z):	
		advance_to_point(target.get_global_transform().origin)


func advance_to_point(point):
	if self_pos.distance_to(point) > 0.1:	
		accelerate()	
		return false # point not reached
	return true # point reached
	
func move_to_target():
	turn_to_target()
	advance_to_target()
	
func accelerate():
	accelerate_by(self.acceleration)

func accelerate_by(acceleration):
	self.current_speed = lerp(self.current_speed, self.max_speed, acceleration)
	self.current_speed = min(self.current_speed, self.max_speed)
	advance()
	
func advance():
	advance_by(self.current_speed)

func advance_by(speed):
	self.translate(Vector3(0.0, 0.0, -speed))

func accelerate_strafe():
	accelerate_strafe_by(self.strafe_acceleration)

func accelerate_strafe_by(acceleration):
	self.current_strafe_speed = lerp(self.current_strafe_speed, self.max_strafe_speed, acceleration)
	self.current_strafe_speed = min(self.current_strafe_speed, self.max_strafe_speed)
	strafe()

func strafe():
	strafe_by(self.current_strafe_speed)

func strafe_by(speed):
	self.translate(Vector3(speed, 0.0, 0.0))
	
func set_navigation(node_path):
	navigation=null
	if node_path != null:
		navigation=get_node(node_path)
		
func set_target(node_path):
	target = null
	if node_path != null:
		target = get_node(node_path)