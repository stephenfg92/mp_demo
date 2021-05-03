extends Node

# Teclas
var teclas

# Representação das entidades
var entidades = {}
var obj_entidade = preload("res://cenas/Entidade.tscn")
onready var cenario = $Cenario

# Conexão simulada
var rede = preload("res://scripts/Rede.gd").new()
var servidor = null
var latencia = 0

# Identificador da entidade controlada por esse cliente. Decidido pelo servidor
var id_entidade_local = null

# Reconciliação
var ultima_atualizacao = null
var predicao = false
var reconciliacao = false
var numero_serial = 0
var comandos_pendentes = []

# Interpolação
var interpolacao = false
var atraso_interpolacao_servidor = null

# Interface
onready var nome = $Interface/Nome
onready var entrada_latencia = $Interface/Entrada
onready var entrada_interpolacao = $Interface/Entrada_interpolacao
onready var entrada_reconciliacao = $Interface/Entrada_reconciliacao
onready var entrada_predicao = $Interface/Entrada_predicao

# Atualizar estado do cliente
func atualizar(delta):
	
	# Recolher dados recebidos do servidor
	processar_mensagens_servidor()
	
	# Significa que este cliente ainda não está conectado ao servidor!
	if id_entidade_local == null:
		return
		
	# Adquirir informações da interface
	interface()
		
	# Processar comandos locais
	processar_comandos(delta)
	
	# Interpolar entidades remotas
	interpolar_entidades()
	
func processar_mensagens_servidor():
	while true:
		var mensagem = self.rede.receber()
		if mensagem == null:
			break
		
		# Ler estado das entidades contidas na mensagem do servidor
		for n in range(mensagem.size()):
			var estado = mensagem[n]
			
			# Se é a primeira vez que vemos essa entidade,
			# é necessário criar uma representação local dela.
			if not estado['id_entidade'] in self.entidades.keys():
				var entidade = obj_entidade.instance()
				cenario.add_child(entidade)
				
				entidade.cor = servidor.cores[estado['id_entidade']]
				entidade.boneco.set_modulate(entidade.cor)
				
				entidade.id_entidade = estado['id_entidade']
				self.entidades[ estado['id_entidade'] ] = entidade
				
				
			var entidade = self.entidades[ estado['id_entidade'] ]
			
			if estado['id_entidade'] == id_entidade_local:
				# Recebida posição da entidade controlada por esse cliente. 
				entidade.position = estado['posicao']
				
				if reconciliacao:
					# Reconciliação com o servidor. Re-aplicar todos comandos ainda não
					# processados pelo servidor
					
					var _n = 0
					while _n < comandos_pendentes.size():
						var comando = comandos_pendentes[_n]
						if comando['numero_serial'] <= estado['ultimo_comando_processado']:
							# Comando já processado pelo servidor. Deve ser eliminado do histórico.
							comandos_pendentes.remove(_n)
						else:
							entidade.aplicar_comando(comando)
							_n = _n + 1
				else:
					# Reconciliação desabilitada. Apagar histórico de comandos.
					comandos_pendentes = []
			else:
				# Recebida posição de entidade remota.
				if not interpolacao:
					# Com a interpolação desligada, devemos simplesmente aplicar a posição recebida
					entidade.position = estado['posicao']
				else:
					# Se a interpolação estiver ligada, adicione a posição ao acumulador da entidade
					var agora = OS.get_system_time_msecs()
					entidade.acumulador_posicoes.push_back( [ agora, estado['posicao'] ] )
					
func interface():
	interpolacao = entrada_interpolacao.is_pressed()
	reconciliacao = entrada_reconciliacao.is_pressed()
	predicao = entrada_predicao.is_pressed()
	latencia = entrada_latencia.get_value() / 2
				
func processar_comandos(delta):
		
	# Adquirir comandos do cliente local
	var vetor = adquirir_comandos()
	
	var comando
	if vetor.x != 0 or vetor.y != 0:
		comando = { 'vetor': vetor, 'delta': delta }
	else:
		# Significa que o jogador não emitiu comandos durante essa atualização
		return
		
	# Enviar comando ao servidor
	comando['numero_serial'] = numero_serial
	numero_serial = numero_serial + 1
	comando['id_entidade'] = id_entidade_local
	servidor.rede.enviar(latencia, comando)
	
	# Prever resposta do servidor
	if predicao:
		self.entidades[id_entidade_local].aplicar_comando(comando)
		
	# Salvar comando no historico para uso nas próximas reconciliações com o servidor
	comandos_pendentes.push_back(comando)
	
func adquirir_comandos():
	var vetor = Vector2.ZERO
	
	if Input.is_action_pressed(teclas['direita']):
		vetor.x += 1
	if Input.is_action_pressed(teclas['esquerda']):
		vetor.x -= 1
	if Input.is_action_pressed(teclas['baixo']):
		vetor.y += 1
	if Input.is_action_pressed(teclas['cima']):
		vetor.y -= 1

	vetor = vetor.normalized()
	
	return vetor
	
func interpolar_entidades():
	
	# Calcular atraso empregado na interpolação
	var agora =  OS.get_system_time_msecs()
	
	# Existem algumas maneiras de calcular o atraso na interpolaçao:
	
	# Fixa. Usa um valor constante enviado pelo servidor. O Counter-Strike trabalha dessa maneira:
	var atraso_interpolacao = agora - atraso_interpolacao_servidor
	
	# Dinâmica. Depende do tick rate do servidor:
	#var taxa_servidor_em_ms = servidor.ms_taxa_atualizacao
	#var atraso_interpolacao = agora - taxa_servidor_em_ms
	
	for n in range(self.entidades.size()):
		var entidade = self.entidades[n]
		
		# Não é necessário interpolar a entidade controlada pelo cliente local.
		if entidade.id_entidade == id_entidade_local:
			continue
			
		var acumulador = entidade.acumulador_posicoes
		
		# Deletando posições velhas
		while acumulador.size() >= 2 and acumulador[1][0] <= atraso_interpolacao:
			acumulador.pop_front()
		
		# Realizando interpolação entre duas posições guardadas no acumulador
		if acumulador.size() >= 2 and acumulador[0][0] <= atraso_interpolacao and atraso_interpolacao <= acumulador[1][0]:
			var T = float( atraso_interpolacao - acumulador[0][0] ) / float( acumulador[1][0] - acumulador[0][0] )
			var posicao_interpolada = lerp( acumulador[0][1], acumulador[1][1], T )
			
			entidade.position = posicao_interpolada
			
func _physics_process(delta):
	atualizar(delta)
