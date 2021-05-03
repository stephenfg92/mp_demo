extends Node

# Clientes conectados e suas respectivas entidades
var clientes = []
var entidades = []
var obj_entidade = preload("res://cenas/Entidade.tscn")
onready var cenario = $Cenario

# Posicoes disponiveis para novas entidades
var posicoes_iniciais = [ 
	Vector2(16, 50),
	Vector2(145, 50),
]

# Cores disponíveis para novas entidades
var cores = [
	Color(0, 0.75, 1, 1),
	Color(1, 0.75, 0, 1),
]

# Valor do atraso de interpolaçao em milissegundos
const atraso_interpolacao = 100

# Ultimo comando processado de cada cliente
var ultimo_comando_processado = {}

# Conexão simulada
var rede = preload("res://scripts/Rede.gd").new()

# Interface
onready var entrada_taxa = $Interface_servidor/Entrada

# Taxa de atualização
var ms_taxa_atualizacao = 50
var hz_taxa_atualizacao = 20
var ultima_atualizacao = null
var acumulador = 0.0

# Determinar taxa de atualização
func definir_taxa_atualizacao(hz):
	if hz == 0:
		return
	ms_taxa_atualizacao = float( 1000.0 / hz )
	
func conectar(cliente):
	# Dados de identificação do cliente
	cliente.servidor = self
	cliente.id_entidade_local = self.clientes.size()
	cliente.atraso_interpolacao_servidor = atraso_interpolacao
	self.clientes.push_back(cliente)
	
	# Instanciando nova entidade para esse cliente
	var entidade = obj_entidade.instance()
	cenario.add_child(entidade)
	entidade.id_entidade = cliente.id_entidade_local
	self.entidades.push_back(entidade)
	self.ultimo_comando_processado[entidade.id_entidade] = -1
	
	# Definindo posição inicial desta nova entidade
	entidade.position = posicoes_iniciais[cliente.id_entidade_local]
	
	# Definindo cor da entidade
	var cor = cores[cliente.id_entidade_local]
	entidade.boneco.set_modulate(cor)

func atualizar():
	# Calcular o tempo decorrido (delta) entre uma atualização e outra
	var agora =  OS.get_system_time_msecs()
	if ultima_atualizacao == null:
		ultima_atualizacao = agora
	var delta = agora - ultima_atualizacao
	ultima_atualizacao = agora
	
	acumulador += delta
	
	if acumulador < ms_taxa_atualizacao:
		return
			
	acumulador = 0.0
	
	interface()
	
	processar_comandos()
	
	enviar_estado_de_jogo()
	
func interface():
	var tick = entrada_taxa.get_value()
	
	if tick == hz_taxa_atualizacao:
		return
		
	hz_taxa_atualizacao = tick
	
	definir_taxa_atualizacao(tick)
	
func validar_comando(comando):
	# Se o comando for diferente que o delta permitido pela taxa de atualização do cliente,
	# o comando deverá ser invalidado. Isso previne que cheaters sejam mais velozes que
	# jogadores honestos!
	
	if comando['delta'] != get_physics_process_delta_time ():
		return false
		
	return true
	
func processar_comandos():
	# Processar comandos enviados pelos clientes
	while true:
		var mensagem = self.rede.receber()		
		
		if mensagem == null:
			break
						
		# Atualizar estado da entidade que enviou a mensagem
		if validar_comando(mensagem):
			var identificador = mensagem['id_entidade']
			self.entidades[identificador].aplicar_comando(mensagem)
			self.ultimo_comando_processado[identificador] = mensagem['numero_serial']
			
func enviar_estado_de_jogo():
	# Enviar estado de jogo a todos clientes conectados
	# Esse estado pode passar por modificações, caso o design do jogo necessite.
	# O Valorant, por exemplo, só envia as posições dos oponentes que o jogador consegue enxergar.
	# Isso evita cheats!
	var estado_de_jogo = []
	
	var quantidade_clientes = self.clientes.size()
	
	# Construindo estado de jogo...
	# Num jogo de verdade, evite usar dicionários.
	# Use no máximo uma array. O ideal seria serializar os dados,
	# transformando-os em uma sequência de digitos binários.
	# Melhor ainda se essa sequência puder ser comprimida!
	for n in range(quantidade_clientes):
		var entidade = self.entidades[n]
		
		estado_de_jogo.push_back(
			{
				'id_entidade': entidade.id_entidade,
				'posicao': entidade.position,
				'ultimo_comando_processado': ultimo_comando_processado[n]
			}
		)
		
	# Enviar estado de jogo a todos clientes conectados
	for n in range(quantidade_clientes):
		var cliente = self.clientes[n]
		cliente.rede.enviar(cliente.latencia, estado_de_jogo)
		
func _process(delta):
	atualizar()
