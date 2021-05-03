extends KinematicBody2D

# Velocidade de movimento
var velocidade = 300

# Identificadr
var id_entidade = null

# Histórico usado para interpolação
var acumulador_posicoes = []

# Animações
var cor = null
var posicao_anterior = position
onready var boneco = $AnimatedSprite
	
func aplicar_comando(comando):
	posicao_anterior = position
	
	var vetor = comando['vetor']
	var delta = comando['delta']
	
	# A partir daqui, estamos tratando de processos específicos do Godot
	# Definindo o último parâmetro dessa função como true,
	# o movimento do personagem é simulado, mas não é desenhado na tela
	var colisao = move_and_collide(vetor * velocidade * delta, true, true, true)
	
	# Se não houver colisão, aplicamos normalmente o comando.
	if colisao == null:
		move_and_collide(vetor * velocidade * delta)
		
	# Se houver, o vetor é projetado ao longo da superfície,
	# fazendo com que o personagem deslize pelas arestas dos colisores.
	# Sem isso, o jogador ficaria "emperrado".
	else:
		var normal = colisao.get_normal()
		
		var projecao = vetor.project(normal)
		
		var novo_vetor = vetor - projecao
		
		move_and_collide(novo_vetor * velocidade * delta)
	
func animar(posicao_anterior, posicao):
	if posicao_anterior == posicao:
		boneco.play('ocioso')
		
	else:
		var vetor_animacao_x = posicao_anterior.x - posicao.x
		var vetor_animacao_y = posicao_anterior.y - posicao.y
		
		if abs(vetor_animacao_x) > 0.03 or abs(vetor_animacao_y) > 0.03:
			boneco.play('andando')
			if vetor_animacao_x > 0:
				boneco.set_flip_h(true)
			else:
				boneco.set_flip_h(false)

	boneco.play()
	
func _process(delta):
	animar(posicao_anterior, position)
	posicao_anterior = position
