extends Node3D

var velocidad = 30.0
var sensibilidad = 0.002
var camara : Camera3D # Definimos el tipo de variable claramente

func _ready():
	setup_lighting_and_env()
	generar_mundo()
	
	# 1. CREAR CÁMARA CORRECTAMENTE
	camara = Camera3D.new()
	add_child(camara) # Primero se añade al mundo...
	camara.make_current() # ...y luego se activa
	camara.position = Vector3(0, 0, 0) # Posición inicial elevada
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

var yaw = 0.0   # Rotación izquierda/derecha
var pitch = 0.0 # Rotación arriba/abajo

func _unhandled_input(event):
	# Captura/Liberación de mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Actualizamos los ángulos basados en el movimiento del ratón
		# Invertimos el signo aquí para cambiar la dirección de rotación
		yaw -= event.relative.x * sensibilidad 
		pitch -= event.relative.y * sensibilidad
		
		# Limitamos el ángulo vertical para no dar la vuelta
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))

func _process(delta):
	if not camara: return
	
	# 1. DIRECCIÓN DE LA MIRADA (Seno y Coseno)
	var direccion_mirada = Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	)
	
	# 2. APLICAR LOOK_AT
	# Importante: Miramos hacia adelante (sumando la dirección a la posición actual)
	camara.look_at(camara.global_position + direccion_mirada, Vector3.UP)

	# 3. MOVIMIENTO
	var movimiento = Vector3.ZERO
	
	# Calculamos 'adelante' basado solo en el giro horizontal (yaw)
	# Nota: En Godot -Z es hacia adelante, por eso usamos los signos así:
	var adelante = Vector3(sin(yaw), 0, cos(yaw)) 
	var derecha = Vector3(sin(yaw + PI/2), 0, cos(yaw + PI/2))
	
	
	if Input.is_key_pressed(KEY_W): movimiento += adelante # Ir hacia adelante
	if Input.is_key_pressed(KEY_S): movimiento -= adelante # Ir hacia atrás
	if Input.is_key_pressed(KEY_A): movimiento += derecha  # Ir izquierda
	if Input.is_key_pressed(KEY_D): movimiento -= derecha  # Ir derecha
	
	# 4. APLICAR MOVIMIENTO AL NODO PRINCIPAL
	if movimiento != Vector3.ZERO:
		camara.position += movimiento.normalized() * velocidad * delta
	if Input.is_key_pressed(KEY_E): camara.position.y += velocidad * delta  # Ir arriba.
	if Input.is_key_pressed(KEY_Q): camara.position.y -= velocidad * delta  # Ir abajo.

func generar_mundo():
	var tamaño = 50 # Un poco más pequeño para que vuele en tu Intel
	var noise = FastNoiseLite.new()
	noise.frequency = 0.005
	
	var multi_mesh = MultiMeshInstance3D.new()
	multi_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	multi_mesh.multimesh = MultiMesh.new()
	multi_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.multimesh.use_colors = true 
	
	var cubo = BoxMesh.new()
	cubo.size = Vector3(1.0, 1.0, 1.0) # Tamaño estándar
	var mat = StandardMaterial3D.new()
	# Cargar textura
	mat.albedo_texture = load("res://dirt.jpg")
	mat.vertex_color_use_as_albedo = true 
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	cubo.material = mat
	multi_mesh.multimesh.mesh = cubo
	multi_mesh.multimesh.instance_count = tamaño * tamaño * tamaño
	
	var i = 0
	for x in range(tamaño):
		for z in range(tamaño):
			for y in range(tamaño):
				var surface = round(noise.get_noise_2d(x, z) * 50)+30
				if y<surface:
					var pos = Transform3D(Basis(), Vector3(x, y, z))
					multi_mesh.multimesh.set_instance_transform(i, pos)
					
					# Lógica de colores como en tus imágenes
					var color_bloque = Color("00a200") # Marrón
					if y < surface - 2: color_bloque = Color("aa8866")
					if y < 25: color_bloque = Color("ff9900") # Amarillo
					
					multi_mesh.multimesh.set_instance_color(i, color_bloque)
					i += 1

	add_child(multi_mesh)

func setup_lighting_and_env():
	var luz = DirectionalLight3D.new()
	luz.shadow_enabled = true
	luz.rotation_degrees = Vector3(-45, 45, 0)
	add_child(luz)
	
	var env_node = WorldEnvironment.new()
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color("0088ff") # Cielo azul
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color.WHITE
	env_res.ambient_light_energy = 0.01
	env_node.environment = env_res
	add_child(env_node)
