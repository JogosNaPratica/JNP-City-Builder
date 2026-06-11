# Classe CustomGridMap
# Autor: Mario Xavier
# Versao: 1.0
# Data: 11/06/2026

class_name CustomGridMap extends GridMap


const TILE_SIZE: float = 10.0

# --- ESTRUTURAS DE DADOS LÓGICAS ---
# { Vector3i(Coordenada_Pivô): Node3D(Instância_da_Cena) }
var _placed_instances: Dictionary = {}

# { Vector3i(Célula_Individual_Ocupada): Vector3i(Coordenada_Pivô) }
var _occupied_cells: Dictionary = {}

func _ready() -> void:
	# Unifica as proporções da matriz nativa às regras do City Builder
	cell_size = Vector3(TILE_SIZE, TILE_SIZE, TILE_SIZE)
	mesh_library = null # Desativa MeshLibrary para forçar uso de Cenas Reais (.tscn)



## Instancia e centraliza uma estrutura 3D completa no grid
func set_composite_structure(pivot_pos: Vector3i, packed_scene: PackedScene, size: Vector2i, orientation: int, structure_id: int) -> bool:

	if not packed_scene: return false
	
	var required_cells = _calculate_footprint(pivot_pos, size, orientation)
	
	# Validação de espaço desimpedida
	for cell in required_cells:
		if _occupied_cells.has(cell):
			print("Espaço obstruído!")
			return false
			
	# CRIAÇÃO DO PIVÔ AUTOMÁTICO:
	# Criamos um nó vazio para ser o centro estável da estrutura no mundo
	var pivot_node = Node3D.new()
	# ... código de instância ...
	pivot_node.set_meta("structure_id", structure_id)
	pivot_node.set_meta("orientation", orientation)
	add_child(pivot_node)
	
	# Instanciamos o prédio real debaixo desse pivô estável
	var instance = packed_scene.instantiate() as Node3D
	pivot_node.add_child(instance)
	
	
		
	# 1. Encontra o centro visual local do bloco baseado no tamanho dele (independente de rotação)
	var local_offset = Vector3(
		(size.x - 1) * TILE_SIZE / 2.0,
		0.0,
		(size.y - 1) * TILE_SIZE / 2.0
	)
	# Empurra a malha interna para que o centro dela fique cravado no nó pivô pai
	instance.position = local_offset
	
	# 2. Agora giramos o nó pai (pivô). Isso garante uma rotação perfeitamente centralizada
	pivot_node.global_transform.basis = _get_custom_basis(orientation)
	
	# 3. Posiciona o pivô exatamente no centro da célula onde o jogador clicou
	var cell_center = map_to_local(pivot_pos)
	pivot_node.global_position = Vector3(cell_center.x, 0.0, cell_center.z)
	
	# Registros lógicos (guardamos o nó pai para remoções futuras)
	_placed_instances[pivot_pos] = pivot_node
	for cell in required_cells:
		_occupied_cells[cell] = pivot_pos
		
	return true

## Desconstrói e limpa a memória de uma estrutura baseada em qualquer uma de suas células ocupadas
func erase_composite_structure(target_cell: Vector3i) -> bool:
	if not _occupied_cells.has(target_cell):
		return false
		
	# Recupera o pivô real através da célula informada
	var pivot_pos = _occupied_cells[target_cell]
	
	# Remove a cena real da hierarquia tridimensional
	if _placed_instances.has(pivot_pos):
		var instance = _placed_instances[pivot_pos]
		if is_instance_valid(instance):
			instance.queue_free()
		_placed_instances.erase(pivot_pos)
		
	# Limpa todas as chaves unitárias indexadas a este pivô
	var cells_to_erase: Array[Vector3i] = []
	for cell in _occupied_cells.keys():
		if _occupied_cells[cell] == pivot_pos:
			cells_to_erase.append(cell)
			
	for cell in cells_to_erase:
		_occupied_cells.erase(cell)
		
	return true

## Retorna a lista completa de células que a estrutura irá pisar, baseado na rotação local
## Versão Corrigida no CustomGridMap.gd

func _calculate_footprint(pivot_pos: Vector3i, size: Vector2i, orientation: int) -> Array[Vector3i]:
	var footprint: Array[Vector3i] = []
	var ortho_basis = _get_custom_basis(orientation)
	
	# Descobre a direção dos eixos baseados na rotação
	var dir_x = Vector3(ortho_basis.x).round()
	var dir_z = Vector3(ortho_basis.z).round()
	
	var step_x = Vector3i(int(dir_x.x), int(dir_x.y), int(dir_x.z))
	var step_z = Vector3i(int(dir_z.x), int(dir_z.y), int(dir_z.z))
	
	# Varre o grid logicamente a partir do clique do mouse
	for x in range(size.x):
		for z in range(size.y):
			var cell = pivot_pos + (step_x * x) + (step_z * z)
			footprint.append(cell)
			
	return footprint

## Substitui o método nativo gerando a Basis correta para rotações em Y (0, 90, 180, 270)
func _get_custom_basis(orthogonal_index: int) -> Basis:
	match orthogonal_index:
		16: # 90 Graus Horário
			return Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
		22: # 180 Graus
			return Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
		10: # 270 Graus Horário
			return Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
		_:   # 0 Graus / Padrão
			return Basis.IDENTITY



func clear_all_structures() -> void:
	# Limpa as instâncias 3D (nós pivô)
	for pivot_cell in _placed_instances:
		var instance = _placed_instances[pivot_cell]
		if is_instance_valid(instance):
			instance.queue_free()
	
	# Limpa os dados lógicos
	_placed_instances.clear()
	_occupied_cells.clear()
	
	# Limpa o GridMap visual nativo
	clear()


func get_placed_instances() -> Dictionary:
	return _placed_instances
