# Classe StructureLibrary
# Autor: Mario Xavier
# Versao: 1.0
# Data: 11/06/2026

class_name StructureLibrary extends Resource

# Aqui o Dicionário é tipado! 
# Chave: int, Valor: StructureData
@export var info: Dictionary[int, StructureData] = {} 


func get_info(id: int) -> StructureData:
	return info.get(id) as StructureData
