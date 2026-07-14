# Classe RoadPlacer
# Sistema de construção de estradas por clique e arraste com Pathfinding
# Autor: Mario Xavier
# Versao: 1.1
# Data: 02/07/2026

class_name RoadPlacer extends Node3D

var builder: Builder
var astar: AStarGrid2D

var is_placing: bool = false
var start_cell: Vector3i
var current_path: Array[Vector2i] = []

var preview_nodes: Array[Node3D] = []
var road_container: Node3D

# --- NOVAS VARIÁVEIS PARA OS MATERIAIS DOS FANTASMAS ---
var red_ghost_mat: StandardMaterial3D
var normal_ghost_mat: StandardMaterial3D

@export var grid_bounds: int = 500

func _ready() -> void:
	road_container = Node3D.new()
	road_container.name = "RoadPreviewContainer"
	add_child(road_container)
	
	astar = AStarGrid2D.new()
	astar.region = Rect2i(-grid_bounds, -grid_bounds, grid_bounds * 2, grid_bounds * 2)
	astar.cell_size = Vector2(1, 1)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN # uso exclusivo com DIAGONAL_MODE_NEVER
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	# --- INICIALIZAÇÃO DOS MATERIAIS 3D VIA CÓDIGO ---
	# Material Vermelho (Sem saldo)
	red_ghost_mat = StandardMaterial3D.new()
	red_ghost_mat.albedo_color = Color(1, 0, 0, 0.5) # Vermelho com 50% de opacidade
	red_ghost_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	red_ghost_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Faz o ghost brilhar sem depender de luzes
	
	# Material Normal (Com saldo - Semi-transparente padrão)
	normal_ghost_mat = StandardMaterial3D.new()
	normal_ghost_mat.albedo_color = Color(1, 1, 1, 0.5) # Branco/Normal com 50% de opacidade
	normal_ghost_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	normal_ghost_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED


## FUNÇÃO AUXILIAR: Varre o nó recursivamente e força o material nas malhas 3D
func _apply_material_recursively(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply_material_recursively(child, material)


## Renderiza os modelos 3D fantasmas na tela
func _render_preview_ghosts() -> void:
	# Limpa fantasmas antigos
	for child in preview_nodes:
		child.queue_free()
	preview_nodes.clear()
	
	if current_path.is_empty(): return
	
	var real_id = builder.structures[builder.current_structure_id]
	var struct_info = builder.structure_library.get_info(builder.structures[builder.current_structure_index])
	
	if not struct_info: return
	
	# Verifica se temos saldo para o trajeto todo
	var total_cost = current_path.size() * struct_info.price
	var can_afford = builder.map.cash >= total_cost
	
	for pos_2d in current_path:
		if struct_info.model_scene:
			var ghost = struct_info.model_scene.instantiate() as Node3D
			road_container.add_child(ghost)
			
			var cell_3d = Vector3i(pos_2d.x, 0, pos_2d.y)
			var local_pos = builder.custom_gridmap.map_to_local(cell_3d)
			
			ghost.global_position = Vector3(local_pos.x, 0.5, local_pos.z)
			
			# --- CORREÇÃO DO BUG AQUI ---
			# Em vez de .modulate, injetamos a override de material de forma recursiva nas malhas internas
			if not can_afford:
				_apply_material_recursively(ghost, red_ghost_mat)
			else:
				_apply_material_recursively(ghost, normal_ghost_mat)
			
			preview_nodes.append(ghost)




## Atualiza os obstáculos dinamicamente lendo o CustomGridMap
func _update_obstacles() -> void:
	astar.fill_solid_region(astar.region, false) # Limpa tudo
	
	# Varre todas as células ocupadas e marca como intransponível no A*
	for cell in builder.custom_gridmap._occupied_cells.keys():
		astar.set_point_solid(Vector2i(cell.x, cell.z), true)


## Inicia o desenho da estrada no primeiro clique
func start_placement(cell: Vector3i) -> void:
	if builder.custom_gridmap.is_cell_item_valid(cell):
		print("Não pode iniciar uma estrada num local ocupado.")
		return
		
	is_placing = true
	start_cell = cell
	_update_obstacles()
	update_preview(cell)


## Atualiza o caminho enquanto o mouse move
func update_preview(end_cell: Vector3i) -> void:
	if not is_placing: return
	
	var start_2d = Vector2i(start_cell.x, start_cell.z)
	var end_2d = Vector2i(end_cell.x, end_cell.z)
	
	# O algoritmo A* calcula o caminho desviando dos sólidos
	current_path = astar.get_id_path(start_2d, end_2d)
	
	_render_preview_ghosts()





## Finaliza e constrói de fato
func confirm_placement() -> void:
	if not is_placing or current_path.is_empty(): 
		cancel_placement()
		return
	
	var struct_info = builder.structure_library.get_info(builder.structures[builder.current_structure_index])
	
	if not struct_info:
		cancel_placement()
		return
	
	var total_cost = current_path.size() * struct_info.price
	
	if builder.map.cash >= total_cost:
		builder.map.cash -= total_cost
		builder.update_cash()
		
		# 1. Coloca todos os blocos crus da estrada no mapa
		for pos_2d in current_path:
			var cell_3d = Vector3i(pos_2d.x, 0, pos_2d.y)
			builder.custom_gridmap.set_composite_structure(
				cell_3d, 
				struct_info.model_scene, 
				struct_info.size, 
				0, 
				struct_info.structure_id
			)
			
		# 2. Roda a atualização de malha (RoadBuilder) para conectar as esquinas e cruzamentos
		for pos_2d in current_path:
			var cell_3d = Vector3i(pos_2d.x, 0, pos_2d.y)
			builder.road_builder.road_fix(cell_3d)
			
		print("Estrada construída com sucesso!")
	else:
		print("Saldo insuficiente para esta rota.")
		
	cancel_placement()


func cancel_placement() -> void:
	is_placing = false
	current_path.clear()
	for child in preview_nodes:
		child.queue_free()
	preview_nodes.clear()
