extends Spatial

export (NodePath) var block_map = null setget set_block_map
func set_block_map(val):
	_clear()
	block_map = val
	_initialize()

export (int) var view_distance = 12 setget set_view_distance
func set_view_distance(val):
	_clear()
	view_distance = val
	view_distance = clamp(view_distance, 1, 256)
	_initialize()
	
export (int) var height = 4 setget set_height
func set_height(val):
	_clear()
	height = val
	_initialize()

export (float) var height_bias = 1.65 setget set_height_bias
func set_height_bias(val):
	_clear()
	height_bias = val
	_initialize()

export (int) var seed_val = 20 setget set_seed_val
func set_seed_val(val):
	_clear()
	seed_val = val
	_initialize()
	
export (int) var octaves = 2 setget set_octaves
func set_octaves(val):
	_clear()
	octaves = val
	_initialize()
	
export (float) var period = 20.0 setget set_period
func set_period(val):
	_clear()
	period = val
	_initialize()
	
export (float) var lacunarity = 2 setget set_lacunarity
func set_lacunarity(val):
	_clear()
	lacunarity = val
	_initialize()
	
export (float) var persistence = 0.5 setget set_persistence
func set_persistence(val):
	_clear()
	persistence = val
	_initialize()

const TREE_MESH = preload("res://scenes/Tree.tscn")

var mesh_node : MeshInstance = null
var noise : OpenSimplexNoise = null

var vertices : PoolVector3Array
var UVs : PoolVector2Array
var normals : PoolVector3Array
var indices : PoolIntArray
var heights : PoolRealArray

var is_initialized = false
var endgame = false

func _generate_vertices():
	vertices = PoolVector3Array()
	var centre_offset = floor(view_distance / 2)
	for x in range(view_distance+1):
		for y in range(view_distance+1):
			var dx = abs(x - view_distance * 0.5)
			var dy = abs(y - view_distance * 0.5)
			var dt = max(dx, dy)
			
			var width = view_distance * 0.5 - 5
			var delta = dt / width
			var gradient = delta * delta
			
			var island_bias = max(0.0, 1.0 - gradient)
			var h = noise.get_noise_2d(x, y) * height_bias * island_bias
			var is_negative = sign(h)
			h *= h + 1
			h *= height * is_negative
			vertices.append(Vector3(x-centre_offset,h,y-centre_offset))

func _generate_UVs():
	UVs = PoolVector2Array()
	var offset = 1.0 / (view_distance)
	for x in range(view_distance+1):
		for y in range(view_distance+1):
			UVs.append(Vector2(offset*x, offset*y))
			
func _generate_indices():
	indices = PoolIntArray()
	for index in range((view_distance+1)*view_distance):
		indices.append(index)
		indices.append(index+(view_distance+1))
		if index != 0 and (index+1) % (view_distance+1) == 0:
			indices.append(index+(view_distance+1))
			indices.append(index+1)

func _generate_normals():
	normals = PoolVector3Array()
	normals.resize(vertices.size())
	for f in range(normals.size()):
		normals[f] = Vector3(0,1,0)
	
	for i in range(0, indices.size()-2, 2):
		var ia = indices[i]
		var ib = indices[i+1]
		var ic = indices[i+2]
		
		if ia==ib or ib==ic or ia==ic:
			continue
		
		var a :Vector3 = vertices[ia]
		var	b :Vector3 = vertices[ib]
		var	c :Vector3 = vertices[ic]
		
		var tangent = c-a
		var bitangent = b-a
		var normal_a = tangent.cross(bitangent)
		
		normals[ia] +=  normal_a
		normals[ib] +=  normal_a
		normals[ic] +=  normal_a
	
	_normalize_normals()
	
func _normalize_normals():
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

func _generate_collision():	
	heights.resize(0)
	
	for i in vertices:
		heights.append(i.y)
	
	heights.invert()
	
	var collider = $Terrain/StaticBody/CollisionShape
	collider.shape.map_depth = view_distance + 1
	collider.shape.map_width = view_distance + 1
	
	collider.shape.set_map_data(heights)

func _generate_mesh():
	_generate_vertices()
	_generate_UVs()
	_generate_indices()
	_generate_normals()
	var mesh = ArrayMesh.new()
	var data = []
	data.resize(ArrayMesh.ARRAY_MAX)
	data[ArrayMesh.ARRAY_VERTEX] = vertices
	data[ArrayMesh.ARRAY_TEX_UV] = UVs
	data[ArrayMesh.ARRAY_INDEX] = indices
	data[ArrayMesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, data)
	return mesh

func _generate_noise():
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	# noise.seed = seed_val
	noise.octaves = octaves
	noise.period = period
	noise.lacunarity = lacunarity
	noise.persistence = persistence

func _generate_spawn_points():
	var coordinate_array = []
	var spawn_array = []
	
	for x in range(-118, 118):
		for y in range(-118, 118):
			coordinate_array.append(Vector2(x, y))
	
	for i in coordinate_array:
		var tree_y = $Terrain/StaticBody/CollisionShape.shape.map_data[((128 - i.x) * 257) + (128 - i.y)]
		spawn_array.append(Vector3(i.x, tree_y, i.y))
	
	var goal_spawn = randi() % spawn_array.size()
	var player_spawn = randi() % spawn_array.size()
	
	$Goal.translation = spawn_array[goal_spawn]
	$Player.translation = spawn_array[player_spawn]

func _generate_trees():
	var coordinate_array = []
	var tree_array = []
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			coordinate_array.append(Vector2(x, y))
	
	coordinate_array.shuffle()
	coordinate_array = coordinate_array.slice(0, coordinate_array.size(), 100)
	
	for i in coordinate_array:
		var tree_y = $Terrain/StaticBody/CollisionShape.shape.map_data[((128 - i.x) * 257) + (128 - i.y)]
		var treespawn = Vector3(i.x, tree_y - 3, i.y)
		if tree_y < 2:
			pass
		elif tree_y < 12:
			tree_array.append(treespawn)
	
	for treee in tree_array:
		randomize()
		var tree_mesh_final = TREE_MESH.instance()
		add_child(tree_mesh_final)
		tree_mesh_final.name = "tree" + str(treee.x) + str(treee.z)
		tree_mesh_final.translation = treee

func _initialize():
	if is_initialized:
		return
	
	if block_map == null:
		return
	
	mesh_node = get_node_or_null(block_map)
	if mesh_node == null:
		return
	
	_generate_noise()
	mesh_node.mesh = _generate_mesh()
	_generate_collision()
	
	_generate_spawn_points()
	#_generate_trees()
	
	$AerialCam/Viewport/GoalCircle.position = Vector2($Goal.translation.x + 128, $Goal.translation.z + 128)
	
	$Control.hide()
	
	is_initialized = true

func _clear():
	if mesh_node != null and is_initialized:
		is_initialized = false
		mesh_node.mesh = null

func _ready():
	randomize()
	_initialize()
	$Goal/MeshInstance/AnimationPlayer.play("rotate")

func _process(delta):
	$Player/Compass/Needle.look_at($TrueNorth.translation, Vector3(0,1,0))
	
	if Input.is_action_just_pressed("reset"):
		is_initialized = false
		_ready()

func _on_Goal_body_entered(body: KinematicBody2D):
	end()

func end():
	if $Goal.translation.distance_to($Player.translation) < 5 && endgame == false:
		endgame = true
		$Player.unfreeze = false
		$Control.show()
		$Control/ButtonHolder/ResetButton.grab_focus()

func _on_QuitButton_pressed():
	get_tree().quit()

func _on_ResetButton_pressed():
	$Player.unfreeze = true
	endgame = false
	_clear()
	randomize()
	_initialize()
