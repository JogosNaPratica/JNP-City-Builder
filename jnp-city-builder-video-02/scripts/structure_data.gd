# Classe StructureData
# Autor: Mario Xavier
# Versao: 1.0
# Data: 11/06/2026

class_name StructureData extends Resource

enum type {ROAD, BUILDING}

@export var structure_id: int  # O ID na sua lista de 'structures'
@export var name: String = "Estrutura"
@export var structure_type: type
@export var price: int = 1000
@export var size: Vector2i = Vector2i(1, 1) # Ex: 1x1, 3x1, 4x2, etc.
@export var model_scene: PackedScene     # O arquivo .tscn 3D da estrutura
