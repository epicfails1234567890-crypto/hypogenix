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
	# 1. LUZ (Sol)
	var sol = DirectionalLight3D.new()
	sol.shadow_enabled = true
	sol.rotation_degrees = Vector3(-45, 0, 0) 
	add_child(sol)
	
	# 2. MATERIAL DEL CIELO (Procedural)
	var sky_material = ProceduralSkyMaterial.new()
	# Colores exactos para el degradado horizontal
	sky_material.sky_top_color = Color(0.0, 0.498, 1.0, 1.0) 
	sky_material.sky_horizon_color = Color(0.0, 1.0, 1.0, 1.0)
	sky_material.ground_bottom_color = Color(0.2, 0.17, 0.15)
	sky_material.ground_horizon_color = Color(0.65, 0.72, 0.81) # Igual al horizonte del cielo
	
	# Creamos el temporizador
	var timer_sol = Timer.new()
	add_child(timer_sol)
	timer_sol.wait_time = 0.1  # Se ejecuta cada 0.1 segundos
	timer_sol.autostart = true
	# Conectamos el timer a la rotación
	timer_sol.timeout.connect(func():
		if sol:
			# Rotamos 0.5 grados en cada intervalo
			sol.rotate_x(deg_to_rad(1.0))
			# ESTO TE DIRÁ EN LA CONSOLA SI ESTÁ ROTANDO O NO
			print("SOL ROTANDO: ", sol.rotation_degrees.x)
# 2. Calcular "Factor de Luz" (0.0 es noche total, 1.0 es mediodía)
			# Usamos el seno de la rotación para saber qué tan arriba está el sol
			var angulo_rad = sol.rotation.x
			var factor_luz = clamp(-sin(angulo_rad), 0.0, 1.0)
			
			# 3. Aplicar oscuridad a los colores originales
			# Multiplicamos el color por el factor_luz para que se apague en la noche
			var color_top_base = Color(0.0, 0.498, 1.0)
			var color_hor_base = Color(0.0, 1.0, 1.0)
			
			sky_material.sky_top_color = color_top_base * factor_luz
			sky_material.sky_horizon_color = color_hor_base * factor_luz
			
			# Opcional: El suelo también debe oscurecerse
			sky_material.ground_horizon_color = sky_material.sky_horizon_color
			
			# 4. Ajustar la energía de la luz para que no haya sombras de noche
			sol.light_energy = factor_luz
	)
	
	timer_sol.start()
	
	# 3. CONFIGURACIÓN DEL ENTORNO
	var sky_res = Sky.new()
	sky_res.sky_material = sky_material
	
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_SKY
	env_res.sky = sky_res
	
	# Iluminación indirecta para que las sombras no sean negras
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_res.ambient_light_sky_contribution = 0.01
	
	var env_node = WorldEnvironment.new()
	env_node.environment = env_res
	add_child(env_node)
