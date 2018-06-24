extends Node

class Group:
	var parent_group_name=null
	var links=null
	var attributes=null

class State:
	var attributes=null
	var group_name=null
	var links=null

class Link:
	var next_state=null
	var type=null
	var timeout=0
	var timer=null
	var condition_owner=null
	var condition_method=null
	var condition_arguments=[]
	var condition_expected

	func add_condition(params):
		condition_owner=params[0]
		condition_method=params[1]
		if params.size()==3:
			condition_expected=params[2]
		elif params.size()==4:
			condition_arguments=params[2]
			condition_expected=params[3]
		pass
	
	func add_timeout(params):
		timeout=params[0]
		if params.size()==2:
			timer=params[1]
		
	func add_timed_condition(params):
		timeout=params[0]
		condition_owner=params[1]
		condition_method=params[2]
		if params.size()==4:
			condition_expected=params[3]
		elif params.size()==5:
			if typeof(params[3])==TYPE_ARRAY:
				condition_arguments=params[3]
				condition_expected=params[4]
			else:
				condition_expected=params[4]
				timer=params[5]
		elif params.size()==6:
			condition_arguments=params[3]
			condition_expected=params[4]
			timer=params[5]

enum LINK_TYPE{
	CONDITION,
	TIMEOUT,
	TIMED_CONDITION
}


var timers={}
var groups={}
var states={}
var state_time=0
var current_state_name=null
var current_state=null
var links=[]

signal state_changed(state_from,state_to,params)

func process(delta=0):
	if current_state_name==null or current_state==null or links.size()==0:
		return
	
	state_time+=delta
	for t in timers.keys():
		timers[t]+=delta
	
	for link in links:
		var condition=true
		var found=false
		if link.type==LINK_TYPE.TIMEOUT or link.type==LINK_TYPE.TIMED_CONDITION:
			if link.timer!=null:
				condition=timers[link.timer]>link.timeout
			else:
				condition=state_time>link.timeout
			found=true
		if condition and (link.type==LINK_TYPE.CONDITION or link.type==LINK_TYPE.TIMED_CONDITION) and link.condition_owner.has_method(link.condition_method):
			condition=condition and (link.condition_owner.callv(link.condition_method,link.condition_arguments)==link.condition_expected)
			found=true
		if condition and found:
			set_state(link.next_state)
			return

func set_state(state_name):
	state_time=0
	var old_state=current_state_name
	
	current_state_name=state_name
	current_state=states[current_state_name]
	_repopulate_links()
	
	emit_signal("state_changed", old_state, new_state, get_current_state_attributes())

#get_groups_attributes
func get_current_state_attributes():
	var attributes
	if current_state.group_name!=null:
		attributes=get_group_attributes(current_state.group_name)
	else:
		attributes={}
	if current_state.attributes!=null:
		for a in current_state.attributes.keys():
			attributes[a]=current_state.attributes[a]
	return attributes

func get_group_attributes(group_name):
	var attributes
	var g=groups[group_name]
	if g.parent_group_name!=null:
		attributes=get_group_attributes(g.parent_group_name)
	else:
		attributes={}
	if g.attributes!=null:
		for a in g.attributes.keys():
			attributes[a]=g.attributes[a]
	return attributes

func _repopulate_links():
	links=[]
	if current_state.group_name!=null:
		_populate_links(current_state.group_name)
	if current_state.links!=null:
		for l in current_state.links:
			links.append(l)

# _fill_links
func _populate_links(group_name):
	if not groups.has(group_name):
		return
	
	var group=groups[group_name]
	if group.parent_group_name!=null:
		_populate_links(group.parent_group_name)
	if group.links!=null:
		for l in group.links:
			links.append(l)

func add_group(group_name,attributes=null,parent_group_name=null):
	var new_group=Group.new()
	if attributes!=null:
		new_group.attributes=attributes
	if parent_group_name!=null:
		new_group.parent_group_name=parent_group_name
	groups[group_name]=new_group

func add_state(state_name,attributes=null,group_name=null):
	var new_state=State.new()
	if attributes!=null:
		new_state.attributes=attributes
	if group_name!=null:
		new_state.group_name=group_name
	states[state_name]=new_state

func link_states(state,next_state,type,params):
	if states.has(state):
		_link_states(states[state],next_state,type,params)
	elif groups.has(state):
		_link_states(groups[state],next_state,type,params)
	

func _link_states(instance,next_state,type,params):
	var link=Link.new()
	link.next_state=next_state
	link.type=type
	match(type):
		LINK_TYPE.CONDITION:
			link.add_condition(params)
		LINK_TYPE.TIMEOUT:
			link.add_timeout(params)
		LINK_TYPE.TIMED_CONDITION:
			link.add_timed_condition(params)
	
	if instance.links==null:
		instance.links=[]
	instance.links.append(link)

func add_timer(name):
	timers[name]=0
