# Classe StructureData
# Autor: Mario Xavier
# Versao: 1.1
# Data: 02/07/2026

class_name StructureData extends Resource

enum type {ROAD, GROUND, BUILDING, FACILITY, SERVICE}

@export_category("System (Gerenciado Automaticamente)")
# Deixe o valor em -1. O sistema irá sobrescrevê-lo permanentemente.
@export var structure_id: int = -1 # O ID na sua lista de 'structures'

@export_subgroup("Model")
@export var name: String = "Estrutura"
@export var model_scene: PackedScene     # O arquivo .tscn 3D da estrutura

@export_subgroup("Map Info")
@export var structure_type: type
@export var size: Vector2i = Vector2i(1, 1) # Ex: 1x1, 3x1, 4x2, etc.

@export_subgroup("Gameplay")
@export var price: int = 1000
