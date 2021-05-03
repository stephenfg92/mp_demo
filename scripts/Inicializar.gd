extends Node2D

onready var cliente1 = $Cliente_1
onready var cliente2 = $Cliente_2
onready var servidor = $Servidor

var teclas_p1 = {
	'direita': 'j1_direita',
	'esquerda': 'j1_esquerda',
	'baixo': 'j1_baixo',
	'cima': 'j1_cima',
}

var teclas_p2 = {
	'direita': 'j2_direita',
	'esquerda': 'j2_esquerda',
	'baixo': 'j2_baixo',
	'cima': 'j2_cima',
}

func _ready():
	servidor.conectar(cliente1)
	cliente1.teclas = teclas_p1
	cliente1.nome.set_text('Cliente 1')
	
	servidor.conectar(cliente2)
	cliente2.teclas = teclas_p2
	cliente2.nome.set_text('Cliente 2')
	
func _input(ev): 
	if ev.is_action_pressed('tela_cheia'): 
		OS.window_fullscreen = !OS.window_fullscreen

func _tela_cheia():
	var ev = InputEventAction.new()
	ev.set_action("tela_cheia")
	ev.set_pressed(true)
	Input.parse_input_event(ev)
