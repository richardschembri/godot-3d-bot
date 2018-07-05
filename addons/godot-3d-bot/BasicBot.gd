extends RigidBody #BasicRigidCharacter

export(float) var max_speed = 2
export(float) var acceleration = 5
export(float) var deacceleration = 20.0

export(float) var max_strafe_speed = 0.25
export(float) var strafe_acceleration = 0.1
export(float) var turn_speed = 0.2

var current_speed = 0;
var current_strafe_speed = 0;
onready var ray_proximity_ground = get_node("armature/ray_proximity_ground")
onready var ray_proximity_front = get_node("armature/ray_proximity_front")
onready var ray_sight_front = get_node("armature/ray_sight_front")

onready var target_tracker = get_node("armature/target_tracker")
onready var path_tracker = get_node("armature/path_tracker")

onready var is_facing_waypoint = false

enum ACTION_STATE{
  SLEEP,
  ADVANCE,
  TURN,
  WAIT
}

export(NodePath) var character_model_path
export(NodePath) var target_node_path
export(NodePath) var navigation_node_path
export(NodePath) var debug_path

var target = null
var navigation = null
var self_pos = Vector3()
const UP=Vector3(0,1,0)
var path = []
var path_endpoint = Vector3()
var nav_path_endpoint = Vector3()
var fsm # finite state machine

const FSM_GROUP_MAIN = "main"
const FSM_STATE_DECIDE = "decide"
const FSM_STATE_WAIT = "wait"
const FSM_STATE_TURN = "turn"
const FSM_STATE_MOVE = "move"
const FSM_STATE_SLEEP = "sleep" 
const bot_states=[FSM_STATE_SLEEP,FSM_STATE_MOVE,FSM_STATE_TURN,FSM_STATE_WAIT]

var current_state_attributes={
	move=false,
	follow_target=false,
	track_target = false,
	track_path = false
}


# Godot Methods
func _ready():
	_init_finite_state_machine()
	add_character_node()
	set_target(target_node_path)
	set_navigation(navigation_node_path)


func _process(delta):
	pass
	
func _physics_process(delta):
	self_pos = self.get_global_transform().origin
	fsm.process(delta)
	_process_current_state(delta)



func _process_current_state(delta):
		
	if current_state_attributes.track_path:
		turn_to_path(delta)
	elif current_state_attributes.track_target:
		turn_to_target(delta)
	
	if current_state_attributes.track_target:
		track_target()
	if current_state_attributes.track_path:
		track_path()
	pass

func _integrate_forces(state):
	if current_state_attributes.track_path:
		advance_to_path(state)
		pass
	elif current_state_attributes.track_target:
		advance_to_target(state)
		pass
	pass



func _init_finite_state_machine():
	fsm = preload("res://addons/godot-3d-bot/finite_state_machine.gd").new()

	fsm.add_group(FSM_GROUP_MAIN, {follow=false})
	fsm.add_state(FSM_STATE_DECIDE, null, FSM_GROUP_MAIN) # no attributes
	fsm.add_state(FSM_STATE_WAIT, {move=false}, FSM_GROUP_MAIN) # do not move whilst in this state
	fsm.add_state(FSM_STATE_TURN, {move=false}, FSM_GROUP_MAIN)
	fsm.add_state(FSM_STATE_MOVE, {move=true}, FSM_GROUP_MAIN)
	fsm.add_state(FSM_STATE_SLEEP, {move=true, follow=false}, FSM_GROUP_MAIN)
	
	fsm.link_states(FSM_STATE_WAIT, FSM_STATE_DECIDE, fsm.LINK_TYPE.TIMEOUT, [0.2])
	fsm.link_states(FSM_STATE_MOVE, FSM_STATE_DECIDE, fsm.LINK_TYPE.TIMEOUT, [2])
	fsm.link_states(FSM_STATE_MOVE, FSM_STATE_DECIDE, fsm.LINK_TYPE.TIMEOUT, [2])
	
	fsm.link_states(FSM_GROUP_MAIN, FSM_STATE_SLEEP, fsm.LINK_TYPE.CONDITION,[self,"is_near_target",true])
	fsm.link_states(FSM_STATE_DECIDE, FSM_STATE_WAIT, fsm.LINK_TYPE.CONDITION,[self,"fsm_has_no_destination",true])
	fsm.link_states(FSM_STATE_DECIDE, FSM_STATE_MOVE, fsm.LINK_TYPE.CONDITION,[self,"fsm_has_no_destination",false])	
	
	fsm.set_state(FSM_STATE_DECIDE)
	
	fsm.connect("state_changed",self,"fsm_state_changed") # connect signals


func fsm_state_changed(old_state_name, new_state_name, new_state_attributes):
	print("Bot State: " + new_state_name)
	
	if new_state_attributes != null:
		for att_key in new_state_attributes.keys():
			current_state_attributes[att_key] = new_state_attributes[att_key]

	if new_state_name == FSM_STATE_MOVE:
		set_path()
		draw_path()
		current_state_attributes.track_path = !has_no_path()
		current_state_attributes.track_target = !has_no_target()
	
func is_in_air():
	return !ray_proximity_ground.is_colliding()

func is_near_target():
	return self_pos.distance_to(target.get_global_transform().origin) < abs(ray_proximity_front.cast_to.z)

func has_no_target():
	return target == null

func has_no_path():
	return navigation == null

func fsm_has_no_destination():
	return has_no_target() && has_no_path()  

func track_target():
	if (target==null):
		return
	var target_origin = target.get_global_transform().origin
	var track_pos =  Vector3(target_origin.x, target_tracker.get_translation().y, target_origin.z) # current_target_ref.get_global_transform().origin
	if target_tracker.get_global_transform().origin != track_pos:
		var tracker_transform = target_tracker.get_global_transform().looking_at(track_pos, UP)
		target_tracker.set_global_transform(tracker_transform)

func track_path():
	if path.size() > 0:
		track_path_point(path[0])

func track_path_point(point):
	var point_pos =  Vector3(point.x, path_tracker.get_translation().y, point.z)
	if (path_tracker.get_global_transform().origin != point_pos):
		var tracker_transform = path_tracker.get_global_transform().looking_at(point_pos, UP)  
		path_tracker.set_global_transform(tracker_transform)

#func turn(right = true):
#	if right:
#		turn_by(self.turn_speed)
#	else:
#		turn_by(-self.turn_speed)
#		
#	is_facing_waypoint = false



func turn_by(turn_radians, delta):
	#self.rotate_y(turn_radians)
	if(turn_radians > turn_speed):
		turn_radians = turn_speed
	elif(turn_radians < - turn_speed):
		turn_radians = -turn_speed
	
	$armature.rotate_y(turn_radians * delta)
	is_facing_waypoint = false

func turn_to_target(delta):
	print("turn_to_target")
	if not turn_to_tracker(target_tracker, delta) && target != null && !is_facing_waypoint: 
		var target_origin = target.get_global_transform().origin
		#face_point(target_origin)

func turn_to_path(delta):
	print("turn_to_path")
	if not turn_to_tracker(path_tracker, delta) && path.size() > 0  && !is_facing_waypoint:
		#face_point(path[0])
		pass

func turn_to_tracker(tracker, delta):
	var tt_rotation = tracker.get_rotation()
	turn_by(tt_rotation.y, delta)
	return tt_rotation.y < -0.1 or tt_rotation.y > 0.1
	
	 
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
	is_facing_waypoint = true

func set_path():
	if !has_no_path():
		path_endpoint = target.get_global_transform().origin
		nav_path_endpoint = navigation.get_closest_point(path_endpoint)
		path = Array(navigation.get_simple_path(self_pos, nav_path_endpoint, true))
		if path.size() > 1:
			path.remove(0) # remove self_pos
	elif target != null:
		path = [target.get_global_transform().origin]

# Returns if target is reached
func advance_to_target(state):
	if self_pos.distance_to(target.get_global_transform().origin) > abs(ray_proximity_front.cast_to.z):	
		advance_to_point(state, target.get_global_transform().origin)
		return false # Target not reached
	return true # Target reached

func advance_to_path(state):
	if path.size() > 0:
		if advance_to_point(state, path[0]):
			path.remove(0)
			
func advance_to_point(state, point):
	if self_pos.distance_to(point) > 1.0: #0.1:	
		#accelerate(state)	
		advance(state)
		return false # point not reached
	return true # point reached

func move_to_path(state):
	turn_to_path()
	advance_to_path(state)	

func move_to_target(state):
	turn_to_target()
	#advance_to_target(state)



func advance(state):
	var delta = state.get_step()
	var lv = state.get_linear_velocity()
	var g = state.get_total_gravity()
	var up = -g.normalized()
	
	lv += g*delta # Apply gravity
	
	var dir = -$armature.get_global_transform().basis.z.normalized() # get_transform().basis[2].normalized()
	var deaccel_dir = dir
	
	if (dir.dot(lv) < max_speed):
		lv += dir * acceleration#*delta
		
	#deaccel_dir = dir.cross(g).normalized()
	
	#var dspeed = deaccel_dir.dot(lv)
	#dspeed -= deacceleration #*delta
	#if (dspeed < 0):
	#	dspeed = 0

	#lv = lv - deaccel_dir*deaccel_dir.dot(lv) + deaccel_dir*dspeed 
	state.set_linear_velocity(lv)

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

func draw_path():
	if debug_path!=null && path.size() > 1:
		var dp_node=get_node(debug_path)
		dp_node.clear()
		dp_node.begin(Mesh.PRIMITIVE_POINTS,null)
		dp_node.add_vertex(path[0])
		dp_node.add_vertex(path[path.size() - 1])
		dp_node.end()
		dp_node.begin(Mesh.PRIMITIVE_LINE_STRIP,null)
		for x in path:
			dp_node.add_vertex(x)
		dp_node.end()

func add_character_node():
	if character_model_path != null:
		$armature.add_child(get_node(character_model_path))

#func accelerate(state):
#	accelerate_by(state, self.acceleration)

#func accelerate_by(state, acceleration):
#	self.current_speed = lerp(self.current_speed, self.max_speed, acceleration)
#	self.current_speed = min(self.current_speed, self.max_speed)
#	advance(state)
