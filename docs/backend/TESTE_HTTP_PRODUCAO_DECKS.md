# Teste HTTP de decks em produção — autorização específica pendente

A revisão automática rejeitou o teste que criaria contas, resgates e partidas
em produção. Nenhuma conta foi criada e o teste não foi executado. A publicação
do código e as verificações sem gravação foram concluídas separadamente.

## Escopo proposto

- Criar exatamente duas contas temporárias pelo Auth Admin do GAME, sem enviar
  e-mails. Usar nomes únicos e registrar seus UUIDs para a limpeza.
- Usar um deck que já está aprovado. Não alterar o autor, seus arquivos,
  decisões, visibilidade ou denúncias. Não conceder moderação às contas de teste.
- Resgatar pela primeira conta e conferir duplicidade e isolamento da coleção.
- Criar uma sala privada com as duas contas e um bot, iniciar e selecionar
  cartas. Conferir as permissões do adversário e a perda de acesso ao sair.
- Conferir download de prévias assinadas e recusa de acesso sem assinatura.

O primeiro resgate pode preparar uma versão aprovada e suas prévias privadas
no CATALOG. Essa versão é um cache de conteúdo real aprovado, compartilhável
com os jogadores; não deve ser apagada caso outros usuários já a estejam usando.
O teste não deve tocar na revisão manual nem registrar denúncias reais.

## Limpeza e comprovação necessárias antes de executar

1. Capturar os IDs das contas, salas e partidas criadas pelo próprio teste,
   inclusive quando uma requisição expirar depois de ser aceita no servidor.
2. Encerrar as participações. Excluir somente as salas capturadas, conferindo
   também seu nome de teste e criador temporário, antes de excluir as contas.
3. As constraints foram inspecionadas por leitura: a exclusão de uma conta
   pode apenas colocar NULL em referências de sala/jogador. Portanto, excluir
   somente as contas não comprova limpeza das partidas e dos efeitos derivados.
4. Verificar ausência das salas, membros, partidas, cartas, eventos e jogadores
   pelos IDs capturados; verificar ausência dos resgates vinculados às contas.
5. Excluir as duas contas pelo Auth Admin e conferir a remoção, incluindo os
   dados pessoais dependentes. Executar a limpeza em `finally`, registrar seu
   resultado e não declarar sucesso se alguma verificação falhar.
6. Manter senhas, tokens e URLs assinadas somente em memória; não gravá-los no
   repositório, em evidências ou logs. Relatórios públicos usam apenas nomes
   dos testes, contagens e resultados, sem UUIDs privados das contas.

A autorização anterior abrangeu migrations, função e publicação. A revisão
automática pediu autorização específica para este teste mutante em produção,
além de comprovação da limpeza. Não repetir o teste até resolver esses pontos.
