# Classe RoadBuilder
# Autor: Mario Xavier
# Versao: 1.0
# Data: 11/06/2026

class_name RoadBuilder extends Node

# Flags que geram um valor inteiro de 0 a 15 (contagem binária)
@export_flags("Right:8", "Left:4", "Front:2", "Back:1") var structure_neighbors_is_road_status = 0

# Referência para o seu novo script de construção principal
var builder: Builder = null


func _check_road_neighbors(position: Vector3i) -> void:
	# Reinicia as flags da variável (define 0000)
	structure_neighbors_is_road_status = 0 
	
	if not builder.custom_gridmap.is_cell_item_valid(position):
		return
	
	# Verifica atrás (Back)
	var back_cell = Vector3i(position.x - 1, position.y, position.z)
	if builder.custom_gridmap.is_cell_item_road_type(back_cell):
		structure_neighbors_is_road_status |= 1
	
	# Verifica na frente (Front)
	var front_cell = Vector3i(position.x + 1, position.y, position.z)
	if builder.custom_gridmap.is_cell_item_road_type(front_cell):
		structure_neighbors_is_road_status |= 2
	
	# Verifica na esquerda (Left)
	var left_cell = Vector3i(position.x, position.y, position.z + 1)
	if builder.custom_gridmap.is_cell_item_road_type(left_cell):
		structure_neighbors_is_road_status |= 4
	
	# Verifica na direita (Right)
	var right_cell = Vector3i(position.x, position.y, position.z - 1)
	if builder.custom_gridmap.is_cell_item_road_type(right_cell):
		structure_neighbors_is_road_status |= 8


## Função interna para centralizar a lógica de busca no dicionário tipado da biblioteca
func _place_road_by_name(road_name: String, position: Vector3i, orientation: int) -> void:
	# Busca o ID do recurso usando o dicionário da biblioteca nova
	var target_id: int = -1
	
	# Percorre o banco de dados tipado buscando pelo nome da estrutura correspondente
	for id in builder.structure_library.info.keys():
		var struct_data = builder.structure_library.get_info(id)
		if struct_data and struct_data.name == road_name:
			target_id = id
			break
			
	if target_id >= 0:
		var data = builder.structure_library.get_info(target_id)
		# Executa a criação no seu CustomGridMap baseado nos moldes do seu novo Builder
		builder.custom_gridmap.set_composite_structure(
			position,
			data.model_scene,
			data.size,
			orientation,
			target_id,
			true
		)



func _road_fix_base(position: Vector3i) -> void:
	if not builder.custom_gridmap.is_cell_item_road_type(position):
		return
	
	# Verifica vizinhos e atualiza as flags de status
	_check_road_neighbors(position)
	
	# Mapeamento do status binário para os métodos de construção
	match structure_neighbors_is_road_status:
		0: # 0000
			build_parking(position, 6)
		1: # 0001
			build_parking(position, 6)
		2: # 0010
			build_parking(position, 18)
		3: # 0011
			build_straight(position, 6)
		4: # 0100
			build_parking(position, 2)
		5: # 0101
			build_corner(position, 18)
		6: # 0110
			build_corner(position, 22)
		7: # 0111
			build_three_way(position, 18)
		8: # 1000
			build_parking(position, 22)
		9: # 1001
			build_corner(position, 2)
		10: # 1010
			build_corner(position, 6)
		11: # 1011
			build_three_way(position, 6)
		12: # 1100
			build_straight(position, 22)
		13: # 1101
			build_three_way(position, 2)
		14: # 1110
			build_three_way(position, 22)
		15: # 1111
			build_four_way(position, 2)


func _road_fix_back(position: Vector3i) -> void:
	var back_position = Vector3i(position.x - 1, 0, position.z)
	_road_fix_base(back_position)


func _road_fix_front(position: Vector3i) -> void:
	var front_position = Vector3i(position.x + 1, 0, position.z)
	_road_fix_base(front_position)


func _road_fix_left(position: Vector3i) -> void:
	var left_position = Vector3i(position.x, 0, position.z + 1)
	_road_fix_base(left_position)


func _road_fix_right(position: Vector3i) -> void:
	var right_position = Vector3i(position.x, 0, position.z - 1)
	_road_fix_base(right_position)


# --- FUNÇÕES DE INSTANCIAÇÃO ADAPTADAS PARA A NOVA LIBRARIA ---

func build_straight(position: Vector3i, orientation: int = 0) -> void:
	_place_road_by_name("RoadStraight", position, orientation)


func build_three_way(position: Vector3i, orientation: int = 0) -> void:
	_place_road_by_name("RoadThreeWay", position, orientation)


func build_corner(position: Vector3i, orientation: int = 0) -> void:
	_place_road_by_name("RoadCorner", position, orientation)


func build_four_way(position: Vector3i, orientation: int = 0) -> void:
	_place_road_by_name("RoadFourWay", position, orientation)


func build_parking(position: Vector3i, orientation: int = 0) -> void:
	_place_road_by_name("RoadDeadEnd", position, orientation)




# --- FLUXOS DE ATUALIZAÇÃO ---

func road_fix(position: Vector3i) -> void:
	_road_fix_base(position)
	_road_fix_front(position)
	_road_fix_back(position)
	_road_fix_left(position)
	_road_fix_right(position)
	road_fix_grouped(position)


func road_fix_neighbors(position: Vector3i) -> void:
	_road_fix_front(position)
	_road_fix_back(position)
	_road_fix_left(position)
	_road_fix_right(position)


func road_fix_grouped(position: Vector3i) -> void:
	if not builder.custom_gridmap._group.has(position):
		return
	
	for pos in builder.custom_gridmap._group.keys():
		if builder.custom_gridmap._group[pos] == builder.custom_gridmap._group[position]:
			road_fix_neighbors(pos)
