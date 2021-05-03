extends Node

var mensagens = []

func enviar(lag, mensagem):
	var agora = OS.get_system_time_msecs()
	
	mensagens.push_back(
		{
			'horario_entrega': agora + lag, 
			'pacote': mensagem,
		}
	)

func receber():
	var agora = OS.get_system_time_msecs()
	
	var tamanho = mensagens.size()
	
	for n in range(tamanho):
		var mensagem = mensagens[n]
		
		if mensagem['horario_entrega'] <= agora:
			mensagens.remove(n)
			return mensagem['pacote']
			
	return null
