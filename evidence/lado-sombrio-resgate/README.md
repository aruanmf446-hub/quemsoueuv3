# Lado Sombrio: resgate manual obrigatório — 2026-11-08

Correção funcional do fluxo existente; sem repaginação. As telas Web usam o motor
Godot 4.7.2 exportado e o cliente real, com transporte sintético somente no teste.
Nenhuma fixture de posse está habilitada no jogo publicado.

## Resultado

- Sem recibo: pack ausente da Biblioteca, busca, detalhe/leitor, referências do
  criador e seleção local/online; acesso direto/configuração também bloqueados.
- Novidades apresenta arte real e botão Resgatar grátis. Abrir/ignorar não concede
  nem limpa o contador +N acima de Novidades.
- Erro de resgate não concede acesso; sucesso libera o deck e remove sua pendência.
- Atualizar consulta preserva o estado do servidor; trocar de conta remove acesso,
  inclusive leitor já aberto. Outras ofertas pendentes continuam contando.
- Presentes legados e suas revelações são preservados; histórico não mostra um
  botão de revelar no novo pack manual.

## Executado

| Validação | Resultado |
|---|---|
| Godot `tests/lado_sombrio_claim/client.gd` | 24 verificações, 0 falhas |
| Catálogo Originals e preservação do El Fuego | 50 verificações, 0 falhas |
| Novidades T28/T30 | 17 + 47 verificações aprovadas |
| Cena principal e hero reais | 72 verificações, 0 falhas, incluindo +1/+2 |
| Duelo local | 87 verificações aprovadas |
| PWA Chromium | 31 verificações, 0 falhas |
| `tools/player_ui/check_design.py` | OK |
| Web Chromium 1672×941 | fluxo completo aprovado |
| Web Chromium iPhone UA, DPR 3, 844×390 | fluxo completo aprovado |
| Web Chromium iPhone UA, DPR 3, 640×360 | fluxo completo aprovado |
| PostgreSQL GAME | bloqueios, resgate, repetição, contas isoladas e ROLLBACK aprovados |

`web/results.json` registra os três fluxos; capturas mostram contador, oferta com
arte, retorno sem contador e Biblioteca liberada. Testes usam mouse/toque reais
nos controles nativos do canvas e bloqueiam tráfego externo ao servidor local.
Não são validação em Safari ou aparelho físico.

## Backend

Migração `20261108220000` aplicada e registrada uma única vez no GAME.
`backend-verification.json`: oferta manual ativa, dez cartas, zero resgates.
Nenhum backfill, promoção de conta, resgate real automático ou mudança em CATALOG,
CHAT/pagamentos. O gerador legado de presentes permanece intacto.

`tests/lado_sombrio_claim/backend.sql` cria duas identidades SQL temporárias dentro
de transação e termina em ROLLBACK. Valida seed sem concessão, feed, visto/revelado
sem resgate, campanha futura sem esconder pendência, inventário, catálogo online,
configuração direta, entrada, início com participantes sem resgate, repetição e
recusa sem sessão. Não é teste HTTP com login OAuth nem partida online simultânea
em dois navegadores. Usuários reais não foram alterados pelos testes.

A migração já aplicada não deve ser executada novamente. O teste SQL exige que ela
já exista. Versões antigas abertas do jogo precisam aceitar a atualização/reabrir
para receber o bloqueio visual do cliente; o bloqueio online é do servidor.
