extends KinematicBody

const MOVE_SPEED = 6
const H_LOOK_SENS = 0.75
const V_LOOK_SENS = 0.75
const GRAVITY = 0.98
const MAX_FALL_SPEED = 12

onready var cam = $Camera
onready var y_velo = 0
onready var butt = 1

onready var unfreeze = true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion && unfreeze:
		cam.rotation_degrees.x -= event.relative.y * V_LOOK_SENS
		cam.rotation_degrees.x = clamp(cam.rotation_degrees.x, -45, 60)
		rotation_degrees.y -= event.relative.x * H_LOOK_SENS
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	
	if Input.is_action_pressed("map"):
		$Map.show()
		
		$Map/MapTween.interpolate_property($Map, "translation", $Map.get_translation(), Vector3(0, -0.4, -1), 0.25, Tween.TRANS_LINEAR)
		$Map/MapTween.start()
	
	if Input.is_action_just_released("map"):
		$Map/MapTween.interpolate_property($Map, "translation", $Map.get_translation(), Vector3(0, -1, 0.5), 0.25, Tween.TRANS_LINEAR)
		$Map/MapTween.start()
		
		yield($Map/MapTween, "tween_all_completed")
		
		$Map.hide()
	
	if Input.is_action_pressed("compass"):
		$Compass.show()
		
		$Compass/CompassTween.interpolate_property($Compass, "translation", $Compass.get_translation(), Vector3(0, 0.1, -0.5), 0.25, Tween.TRANS_LINEAR)
		$Compass/CompassTween.start()
	
	if Input.is_action_just_released("compass"):
		$Compass/CompassTween.interpolate_property($Compass, "translation", $Compass.get_translation(), Vector3(0, -0.25, 0.25), 0.25, Tween.TRANS_LINEAR)
		$Compass/CompassTween.start()
		
		yield($Compass/CompassTween, "tween_all_completed")
		
		$Compass.hide()

func _physics_process(delta):
	var move_vec = Vector3()
	if unfreeze:
		if Input.is_action_pressed("walk_forwards"):
			move_vec.z -= 1
		if Input.is_action_pressed("walk_backwards"):
			move_vec.z += 1
		if Input.is_action_pressed("walk_left"):
			move_vec.x -= 1
		if Input.is_action_pressed("walk_right"):
			move_vec.x += 1
	move_vec = move_vec.normalized()
	move_vec = move_vec.rotated(Vector3(0, 1, 0), rotation.y)
	move_vec *= MOVE_SPEED
	move_vec.y = y_velo
	move_and_slide(move_vec, Vector3(0, 1, 0))
	
	var grounded = is_on_floor()
	y_velo -= GRAVITY
	if grounded and y_velo <= 0:
		y_velo = -0.1
	if y_velo < -MAX_FALL_SPEED:
		y_velo = -MAX_FALL_SPEED
