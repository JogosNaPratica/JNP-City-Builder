@tool
# Classe StructureLibrary
# Autor: Mario Xavier
# Versao: 1.1.1
# Data: 13/07/2026

class_name StructureLibrary extends Resource

@export_category("Configurações do Banco de Dados")
## Pasta onde você salva todos os arquivos .tres do tipo StructureData
@export_dir var structures_folder: String = "res://resources/structures"

@export_group("Dicionarios da Biblioteca")
# Chave: ID (int), Valor: StructureData
@export var info: Dictionary[int, StructureData] = {}

# Chave: StructureData.type (int do Enum), Valor: Array[StructureData]
# Útil para carregar abas específicas na UI (ex: Aba de Ruas, Aba de Serviços)
@export var categorized_info: Dictionary = {}

## Cria os botoes no inspetor
@export_category("Atualiza Estruturas")
@export_tool_button("Update Structures") var _btn_acao: Callable = _refresh_library
@export_category("Use com CUIDADO")
@export_tool_button("Reset IDs") var _btn_reset_ids: Callable = _reset_ids




## Retorna uma estrutura específica pelo ID
func get_info(id: int) -> StructureData:
	return info.get(id)


## Retorna a lista completa de estruturas de uma categoria específica
func get_category(category_type: int) -> Array:
	if categorized_info.has(category_type):
		return categorized_info[category_type]
	return []


# --- SISTEMA DE AUTOMAÇÃO ---

#func _refresh_library(value: bool) -> void:
func _refresh_library() -> void:
	if not Engine.is_editor_hint():# or not value:
		return
		
	print("\n[StructureLibrary] Iniciando varredura e categorização...")
	
	# 1. Limpa os dicionários antigos
	info.clear()
	categorized_info.clear()
	
	# Inicializa as listas do dicionário de categorias baseado nos valores do Enum
	for enum_val in StructureData.type.values():
		categorized_info[enum_val] = []
	
	var dir = DirAccess.open(structures_folder)
	if not dir:
		printerr("[StructureLibrary] ERRO: Pasta não encontrada -> ", structures_folder)
		return
		
	var highest_id: int = -1
	var loaded_structures: Array[StructureData] = []
	
	# PASSO 1: Carrega todos os resources e acha o maior ID
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res_path = structures_folder + "/" + file_name
			var res = ResourceLoader.load(res_path)
			
			if res is StructureData:
				loaded_structures.append(res)
				if res.structure_id > highest_id:
					highest_id = res.structure_id
		
		file_name = dir.get_next()
		
	# PASSO 2: Atribui IDs inéditos e organiza as estruturas nas categorias
	for struct in loaded_structures:
		# Verifica se é uma estrutura nova
		if struct.structure_id == -1:
			highest_id += 1
			struct.structure_id = highest_id
			ResourceSaver.save(struct, struct.resource_path)
			print(" -> Nova estrutura: '", struct.name, "' | ID: ", struct.structure_id)
			
		# Adiciona ao dicionário geral
		info[struct.structure_id] = struct
		
		# Adiciona ao dicionário de categorias
		if categorized_info.has(struct.structure_type):
			categorized_info[struct.structure_type].append(struct)
		
	print("[StructureLibrary] Concluído! Total: ", info.size(), " estruturas registradas.")
	
	# Mostra o resumo das categorias no console
	for cat_key in categorized_info.keys():
		var amount = categorized_info[cat_key].size()
		# Pega o nome do Enum em texto para ficar legível no console
		var cat_name = StructureData.type.keys()[cat_key] 
		print("  - Categoria [", cat_name, "]: ", amount, " itens.")
	
	# Salva a própria biblioteca atualizada de volta no arquivo .tres físico
	if not resource_path.is_empty():
		var save_result = ResourceSaver.save(self, resource_path)
		if save_result == OK:
			print("[StructureLibrary] Sucesso! Arquivo da biblioteca salvo permanentemente no disco.")
		else:
			printerr("[StructureLibrary] ERRO ao salvar o arquivo da biblioteca. Código: ", save_result)
	else:
		printerr("[StructureLibrary] AVISO: Não foi possível salvar automaticamente porque este Resource ainda não foi salvo no disco nenhuma vez (resource_path está vazio).")
	
	# Atualiza a interface gráfica do Inspetor da Godot
	notify_property_list_changed()


func _reset_ids() -> void:
	
	if not Engine.is_editor_hint():# or not value:
		return
		
	print("\n[StructureLibrary] Iniciando varredura...")
	
	var dir = DirAccess.open(structures_folder)
	if not dir:
		printerr("[StructureLibrary] ERRO: Pasta não encontrada -> ", structures_folder)
		return
	
	var loaded_structures: Array[StructureData] = []
	
	# PASSO 1: Carrega todos os resources e acha o maior ID
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res_path = structures_folder + "/" + file_name
			var res = ResourceLoader.load(res_path)
			
			if res is StructureData:
				loaded_structures.append(res)
		
		file_name = dir.get_next()
	
	# PASSO 2: Atribui IDs -1 para todas as estruturas
	for struct in loaded_structures:
		struct.structure_id = -1
		ResourceSaver.save(struct, struct.resource_path)
		print(" -> Estrutura resetada: '", struct.name, "' | ID: ", struct.structure_id)
			
	
	print("[StructureLibrary] Concluído! Total: ", info.size(), " estruturas registradas.")
	
	
	# PASSO 3: Limpa a biblioteca e salva o arquivo .tres físico
	
	info.clear()
	categorized_info.clear()
	
	if not resource_path.is_empty():
		var save_result = ResourceSaver.save(self, resource_path)
		if save_result == OK:
			print("[StructureLibrary] Sucesso! Arquivo da biblioteca esvaziado.")
		else:
			printerr("[StructureLibrary] ERRO ao salvar o arquivo da biblioteca. Código: ", save_result)
	else:
		printerr("[StructureLibrary] AVISO: Não foi possível salvar automaticamente porque este Resource ainda não foi salvo no disco nenhuma vez (resource_path está vazio).")
	
	_refresh_library()
	notify_property_list_changed()
