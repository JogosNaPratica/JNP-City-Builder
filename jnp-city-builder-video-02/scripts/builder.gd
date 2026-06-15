# Classe Builder
# Autor: Mario Xavier
# Versao: 1.0
# Data: 11/06/2026

class_name Builder extends Node3D

# --- CONSTANTES ---
const TILE_SIZE: float = 10.0

# --- REFERÊNCIAS DO INSPECTOR ---
@export_category("Componentes do Sistema")
@export var custom_gridmap: CustomGridMap # Vincule seu nó CustomGridMap aqui
@export var selector: Node3D        # O nó pai do seletor que será interpolado via Lerp
@export var selector_sprite: Sprite3D # O sprite real que exibe a textura de grade
@export var preview_container: Node3D # O container onde instanciamos o modelo 3D temporário (fantasma)
@export var cash_display: Label # O Label onde exibimos o valor atual na carteira do mapa

@export_category("Câmera RTS")
#@export var camera_base: Node3D # Nó pai/pivô usado para translação da câmera
@export var camera_3d: Camera3D # A câmera de visualização do mundo

@export_category("Configurações do Jogo")

@export var structure_library: StructureLibrary

# --- VARIÁVEIS INTERNAS ---
var current_structure_id: int = 0
var current_rotation_index: int = 0 # Define o multiplicador de 90° (0, 1, 2, 3)
var virtual_ground_plane: Plane
var grid_target_position: Vector3 = Vector3.ZERO

var structures: Array[int] = [0, 1, 2]

var map: DataMap # DataMap.new()

func _ready() -> void:
	virtual_ground_plane = Plane(Vector3.UP, 0.0)
	map = create_new_map()
	
	# Proteção contra falhas de inicialização de escala
	if selector: selector.scale = Vector3.ONE
	if selector_sprite: selector_sprite.scale = Vector3.ONE
	
	update_preview()
	structures = _load_structures_from_library()

func _process(delta: float) -> void:
	#_handle_camera_movement(delta)
	_project_mouse_to_grid()
	
	# INTERPOLAÇÃO ATÔMICA: Modifica unicamente a posição para respeitar a escala do Sprite
	if selector:
		selector.position = selector.position.lerp(grid_target_position, delta * 25.0)

func _unhandled_input(event: InputEvent) -> void:
	if structures.size() == 0 or not custom_gridmap: return
	var current_build = structures[current_structure_id]
	
	# Pega o mapeamento da célula base sob o mouse
	var current_cell = custom_gridmap.local_to_map(grid_target_position)
	current_cell.y = 0

	# Click Esquerdo: Construir
	#if event.is_action_pressed("build"): # Substitua por sua action (ex: "left_click")
	#	if map.cash >= current_build.price:
	#		var orientation = _get_orthogonal_index()
	#		var success = custom_gridmap.set_composite_structure(current_cell, current_build.model_scene, current_build.size, orientation)
	#		if success:
	#			map.cash -= current_build.price
	#			print("Construído! Saldo atual: ", map.cash)#wallet)
	#			update_cash()
	#	else:
	#		print("Saldo insuficiente.")
	
	action_build(event)

	# Click Direito: Destruir
	if event.is_action_pressed("demolish"): # Substitua por sua action (ex: "right_click")
		custom_gridmap.erase_composite_structure(current_cell)

	# Clique Direito + SHIFT: Rotacionar
	if event.is_action_pressed("rotate"): # Substitua por sua action (ex: "rotate")
		current_rotation_index = wrap(current_rotation_index + 1, 0, 4)
		update_preview()

	# Tecla I: Próxima Estrutura
	if event.is_action_pressed("structure_next"):
		current_structure_id = wrap(current_structure_id + 1, 0, structures.size())
		update_preview()
	
	
	# Tecla U: Estrutura Anterior
	if event.is_action_pressed("structure_previous"):
		current_structure_id = wrap(current_structure_id - 1, 0, structures.size())
		update_preview()
	
	action_load()
	action_save()






func _adjust_selector_visual_size(structure_size: Vector2i) -> void:
	if not selector_sprite or not selector_sprite.texture: return
	
	# Usamos a atribuição direta por inteiros para evitar problemas de escopo de Enum no 3D:
	# 1 = TEXTURE_REPEAT_ENABLED
	selector_sprite.set("texture_repeat", 1) 
	
	# 2 = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	selector_sprite.set("texture_filter", 2)
	
	selector_sprite.region_enabled = true
	
	var texture_dim = selector_sprite.texture.get_size()
	
	# Altera o rect da região multiplicando os pixels pelo tamanho lógico das células
	selector_sprite.region_rect = Rect2(
		0, 0,
		texture_dim.x * structure_size.x,
		texture_dim.y * structure_size.y
	)
	
	# Modifica o pixel_size para expandir os metros físicos sem quebrar a escala tridimensional
	selector_sprite.pixel_size = TILE_SIZE / texture_dim.x


## Função auxiliar para formatar no padrão 1.000.000,00
func _format_currency_br(value: float) -> String:
	# Transforma em string com 2 casas decimais
	var s = "%.2f" % value
	var parts = s.split(".")
	var integer_part = parts[0]
	var decimal_part = parts[1]
	
	var result = ""
	var count = 0
	
	# Caminha pelo número de trás para frente para colocar os pontos
	for i in range(integer_part.length() - 1, -1, -1):
		result = integer_part[i] + result
		count += 1
		if count == 3 and i != 0:
			result = "." + result
			count = 0
			
	return result + "," + decimal_part


func _get_orthogonal_index() -> int:
	match current_rotation_index:
		1: return 16 # 90 Graus
		2: return 22 # 180 Graus
		3: return 10 # 270 Graus
		_: return 0  # 0 Graus


func _load_structures_from_library(type = null) -> Array:
	structures.clear()
	return structure_library.data.keys()


## Converte coordenadas de tela em coordenadas tridimensionais lógicas do Grid
func _project_mouse_to_grid() -> void:
	if not camera_3d or not custom_gridmap: return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera_3d.project_ray_origin(mouse_pos)
	var ray_normal = camera_3d.project_ray_normal(mouse_pos)
	
	var intersection = virtual_ground_plane.intersects_ray(ray_origin, ray_normal)
	if intersection != null:
		var raw_cell = custom_gridmap.local_to_map(intersection)
		raw_cell.y = 0
		
		var orientation_idx = _get_orthogonal_index()
		
		# 1. Pega o centro da célula atual que o mouse está apontando
		var cell_center = custom_gridmap.map_to_local(raw_cell)
		
		# 2. Alvo do movimento (o nó raiz do seletor seguirá este ponto)
		grid_target_position = Vector3(cell_center.x, 0.05, cell_center.z)
		
		# 3. Aplica a rotação na raiz do seletor (faz tudo girar no eixo central da célula)
		selector.global_transform.basis = custom_gridmap._get_custom_basis(orientation_idx)





func action_build(_event: InputEvent) -> void:
	if structures.size() == 0 or not custom_gridmap: return
	var current_build = structure_library.get_data(current_structure_id)
	
	# Pega o mapeamento da célula base sob o mouse
	var current_cell = custom_gridmap.local_to_map(grid_target_position)
	current_cell.y = 0
	
	var event = _event
	# Click Esquerdo: Construir
	if event.is_action_pressed("build"): # Substitua por sua action (ex: "left_click")
		if map.cash >= current_build.price:
			var orientation = _get_orthogonal_index()
			var success = custom_gridmap.set_composite_structure(current_cell,
				current_build.model_scene,
				current_build.size,
				orientation,
				current_build.structure_id
			)
			
			if success:
				map.cash -= current_build.price
				print("Construído! Saldo atual: ", map.cash)
				update_cash()
		else:
			print("Saldo insuficiente.")




func action_save():
	if Input.is_action_just_pressed("save"):
		print("Salvando cidade...")
		map.structures.clear() # Limpa a lista do Resource DataMap
		
		# Acessamos o dicionário que mapeia [Pivô -> Instância]
		var placed_dict = custom_gridmap.get_placed_instances()
		
		for pivot_cell in placed_dict.keys():
			var data_struct = StructureDataMap.new()
			data_struct.grid_position = pivot_cell
			
			# Precisamos recuperar a orientação e o índice daquela instância específica
			# Dica: Você pode armazenar essas infos em metadados na instância ao criá-la
			var instance = placed_dict[pivot_cell]
			data_struct.orientation = instance.get_meta("orientation", 0)
			data_struct.structure_id = instance.get_meta("structure_id", 0)
			
			map.structures.append(data_struct)
			
		ResourceSaver.save(map, "res://map_city.res")#"user://map_city.res")
		print("Cidade salva com sucesso!")



func action_load():
	if Input.is_action_just_pressed("load"):
		print("Carregando cidade...")
		
		# 1. Limpa o mapa atual completamente
		custom_gridmap.clear_all_structures() # Crie este método para dar queue_free em tudo
		
		map = ResourceLoader.load("res://map_city.res")#"user://map_city.res")
		if not map: 
			map = create_new_map()
			return
			
		# 2. Reconstrói cada estrutura
		for data in map.structures:
			var build_info = structure_library.get_data(data.structure_id)
			
			# CONVERSÃO AQUI: 
			# data.position é Vector2i, transformamos em Vector3i para o GridMap
			var pivot_pos_3d = Vector3i(data.grid_position.x, data.grid_position.y, data.grid_position.z)
			
			# Agora passamos o pivot_pos_3d (Vector3i) corretamente
			# Chama a função mágica que você criou
			custom_gridmap.set_composite_structure(
				pivot_pos_3d, 
				build_info.model_scene, 
				build_info.size, 
				data.orientation,
				build_info.structure_id
			)
			
		update_cash()
		print("Cidade carregada!")


func create_new_map() -> DataMap:
	var new_map = DataMap.new()
	new_map.cash = 1000000
	return new_map




func update_cash() -> void:
	if not map: return
	
	# 1. Formata o número com separadores de milhar (ponto)
	# O método format_number_br abaixo cuidará da estética
	var formatted_money = _format_currency_br(map.cash)
	
	if cash_display:
		cash_display.text = "R$ " + formatted_money
	else:
		print("Cash Display não atribuído. Dinheiro atual: R$ ", formatted_money)


## Redimensiona e alinha o Sprite3D e o modelo fantasma
func update_preview() -> void:
	if structures.size() == 0 or not selector_sprite or not custom_gridmap: return
	var current_build = structure_library.get_data(current_structure_id)
	
	# 1. Reconfigura o Sprite3D da grade do chão (Sempre centralizado em ZERO)
	_adjust_selector_visual_size (current_build.size)
	selector_sprite.position = Vector3.ZERO
	
	# 2. Limpa o container antigo do modelo fantasma 3D
	for child in preview_container.get_children():
		child.queue_free()
		
	# 3. Instancia o novo modelo fantasma
	if current_build.model_scene:
		var ghost_model = current_build.model_scene.instantiate() as Node3D
		preview_container.add_child(ghost_model)
		
		# CORREÇÃO DE ESCOPO: O offset do mesh é calculado aqui usando o tamanho do prédio atual!
		var local_offset = Vector3(
			(current_build.size.x - 1) * TILE_SIZE / 2.0,
			0.0,
			(current_build.size.y - 1) * TILE_SIZE / 2.0
		)
		
		# Aplica o deslocamento apenas na malha visual tridimensional
		ghost_model.position = local_offset + Vector3(0, 1.5, 0)
		selector_sprite.position = local_offset
		
