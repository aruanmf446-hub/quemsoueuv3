# Áreas aprovadas, histórico e visitante — 2026-11-09

Escopo atual autorizado: proteção das áreas aprovadas; corrigir histórico de
Novidades; convite genérico borrado de login na Biblioteca. O dono alterou a
preferência inicial de ocultar tudo para mostrar esse convite. Não libera o Lado
Sombrio sem conta/resgate nem muda os decks gratuitos anteriores.

## Comportamento

Visitante vê uma ilustração genérica borrada (verso privado já existente), sem
nome/carta/ID do Lado Sombrio. O botão abre a rota account existente. Após login,
o pack continua exigindo resgate real em Novidades. Não foi criado nenhum grant.

Histórico usa recibos claimed, independentemente da etapa visual revealed. A
consulta qse_rewards_inventory continua funcionando quando o feed de campanhas
falha. O botão Atualizar histórico consulta apenas o inventário, sob a sessão atual;
clear/generation/sequence impedem respostas de outra conta. Não há polling novo.
Erro de inventário não fabrica recibos nem informa vazio como sucesso.

## Proteção

AGENTS.md, CLAUDE.md e instruções do Copilot apontam para a confirmação obrigatória:
“Você já aprovou [área]. Gostaria de alterar [mudança específica]?”
Há CODEOWNERS, política de blobs/padrões e check nos PRs/main e antes do Pages.
O script e política usados no CI vêm da revisão-base confiável; mudar a lista no
próprio commit não desbloqueia os arquivos. Exceção requer variável do repositório
com SHA completo, áreas e confirmação específica do dono. Não há comando de
rebaseline automático incluído para a IA usar.

Limitação administrativa: arquivos/CI não impedem por si só um push ao GitHub.
Para bloquear merge/push ignorando verificações, o dono precisa tornar o check
**Approved scope guard** obrigatório nas regras da main e exigir revisão CODEOWNERS.
O acesso de gerenciamento à API GitHub está bloqueado neste ambiente; não declarar
que ruleset/proteção de branch foi ativado. Configuração: Settings → Rules → Rulesets
(ou Branches) → main → status check obrigatório, revisão do dono, sem bypass.
Uma IA com credencial administrativa do dono não é distinguida automaticamente dele.

## Executado

- 12 verificações Godot do histórico/feed com falha, recibos não revelados, visitante,
  arte genérica, bloqueio local e rota de login; zero falhas.
- Resgate Lado Sombrio: 24 verificações; Novidades T28: 17; T30: 47; fixture de
  histórico sem campanha; todos aprovados no Godot 4.7.2.
- Web real Chromium: 1672×941, iPhone UA/DPR3 em 844×390 e 640×360; convite e
  histórico capturados, nenhum erro de script. Fixtures de conta e recibos locais,
  com tráfego externo bloqueado; não é Safari/iPhone físico ou login OAuth real.
- Guard: dez testes unitários e integração git real com rebaseline indevido negado,
  exceção exata aceita e confirmação antiga negada. YAML e design checker aprovados.
- Nenhuma alteração de Supabase, compras, autenticação, amizade, música ou skins.
