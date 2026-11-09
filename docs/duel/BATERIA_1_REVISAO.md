# Bateria 1 — ajustes apontados pelo dono em 2026-11-09

Implementação em branch para revisão; **não publicada na main/Pages**.

| Item | Implementação |
|---|---|
| 1 | Títulos Decks populares e Decks recentes sem contagem; demais títulos preservados. |
| 2 | Visitante mantém convite no topo e ganha cartão borrado depois dos decks, com o mesmo encaixe da grade e rota account ao tocar. |
| 3 | Lorena omitida na galeria, busca, coleções e prévia de Personagens; modelos, inventário e equipamentos da conta preservados. |
| 4 | Criar sala local/online sem deck pré-selecionado; mantém múltipla seleção/✓/✕ e valida pelo menos um deck antes da RPC. Editar sala existente conserva a seleção atual. |
| 5 | Comprados oculto enquanto COMMERCE_ENABLED está desativado; lógica futura preservada. |
| 6 | Avisos de Favoritos, Bombando e Meus decks com largura de leitura, sem letras empilhadas. |
| 7 | Somente no Mata-Mata: mini player inferior direito, aviso de cinco segundos após troca real de faixa; some sem pausar música. Demais rotas e player do lobby mantidos. |
| 8 | Criar sala/Cancelar fora da rolagem; botões com tamanho original, rodapé reserva espaço para o aviso musical sem sobrepor o resumo. Sem mudar base, escala ou áreas seguras. |

## Confirmações do dono

- Biblioteca: após a pergunta de área aprovada, respondeu **“Pode”** para retirar
  os contadores. Para o convite respondeu **“Aparece nos dois lugares”**.
- Personagens: após pergunta sobre ocultar Lorena, respondeu **“Tá certo”** e seguiu
  o levantamento. Ao encerrar, pediu começar pelas correções anteriores.
- Músicas: após perguntar se a mudança seria somente no Mata-Mata, respondeu
  **“Exato”**. Música/playlist não foram reconstruídas.
- Inicialmente pediu apenas uma lista. Depois autorizou iniciar:
  **“A gente pode começar primeiro fazer aquelas correções que eu já apontei.”**
- O comando posterior **“Continue”** manteve esse escopo.

## Próxima bateria — não implementada aqui

Avatar próprio aparece vazio no lobby da sala, embora um personagem tenha sido
escolhido. Investigar o vínculo entre membro, skin equipada e modelo real existente.
Conferir no catálogo se o clipe de lobby é a animação 2; reproduzi-lo em loop no
lobby e na apresentação individual dos jogadores durante o sorteio.
Preservar modelos, skins e clipes existentes. O dono adiou explicitamente esse item.

## Validação

- Godot 4.7.2: 24 verificações em cada perfil 1672×941, iPhone 844×390 e 640×360.
- Formulário T26: 25 verificações, zero falhas.
- Cena principal e rotas reais: 90 verificações, zero falhas.
- Partida local completa: 90 verificações, até encerramento.
- Web exportado no Chromium: desktop e iPhone UA/DPR3 nas duas janelas; criação
  vazia bloqueada, rodapé estável após rolar, três avisos legíveis, aviso de música
  expira, cartão de visitante abre account e Lorena não aparece. Zero erros de script.
- Design checker e diff check aprovados. Dados de conta/estatística/música de teste,
  sem tráfego externo nos testes Web. Não são testes em Safari ou aparelho físico.
- O backend Dummy headless emite avisos de recursos/RIDs no encerramento dos runners;
  isso fica nos logs. Não declarar logs nativos completamente livres de erros.
  A inspeção visual usa o build Web real; não foi validado áudio físico pelo fixture.

Evidências: `evidence/duel-polish-batch-1/`.

## Publicação e proteção

A política ativa continua intacta. Três arquivos congelados foram alterados dentro
do escopo confirmado: Biblioteca, player e seletor de skins. O registro proposto
em `evidence/duel-polish-batch-1/proposed-protected-files.json` **não foi aplicado**.

Antes de publicar, é necessário confirmar a atualização somente desses registros
na política e definir pelo dono a autorização QSE_APPROVED_CHANGE para o commit
final e áreas decks, musicas, skins e protecao. A IA não deve criar essa variável,
remover checks ou forçar push para contornar a regra. Não reabrir outras áreas.
Nenhuma mudança de autenticação, Supabase, preços, transações ou regras de batalha.
