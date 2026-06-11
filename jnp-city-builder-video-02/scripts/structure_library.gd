# Classe StructureLibrary
# Autor: Mario Xavier
# Versao: 1.0
# Data: 11/06/2026

class_name StructureLibrary extends Resource

# Aqui o Dicionário é tipado! 
# Chave: int, Valor: StructureData
@export var data: Dictionary[int, StructureData] = {} 

func get_structure(id: int) -> StructureData:
	return data.get(id) as StructureData


func get_data(id: int) -> StructureData:
	return data.get(id) as StructureData
