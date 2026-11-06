# Teste HTTP de decks — contas QA existentes

O repositório já tem o workflow `.github/workflows/community-e2e.yml`, com as
contas OWNER, READER e R1 por GitHub Secrets. As contas existentes devem ser
preservadas: não criar substitutas, redefinir senhas ou excluir essas contas.
As credenciais ficam no Actions e não devem ser exportadas para esta conversa.

## Verificação executada

A etapa `access` foi executada na branch `work/deck-runtime-corrections`:
[run 42271709687](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42271709687),
commit `8efcda2`, **Success**, duração 31 s.

O script `tools/e2e/community_access.py` exige login bem-sucedido de OWNER,
READER e R1 e valida, para cada uma, os contratos de `qse_community_inventory`,
`qse_community_decks` e `qse_duel_decks`. A execução falha se faltar qualquer
credencial, se o login falhar ou se uma consulta retornar contrato inválido.
Não imprime e-mails, senhas, tokens ou conteúdo privado dos decks.

Essa etapa não cria contas, decks, resgates, denúncias ou salas. É a etapa
padrão do workflow; as etapas antigas que gravam dados continuam manuais.
A etapa antiga `community` registra denúncias e não deve ser confundida com
uma consulta sem gravação.

## Próximo teste: resgate e partida nas contas QA

O teste anterior com criação de contas temporárias foi rejeitado pela revisão
automática e não foi executado. O plano corrigido reutiliza OWNER/READER:

- Confirmar com o dono o resgate e a partida de teste nessas contas existentes.
- Registrar a coleção anterior; não apagar resgates que já existiam.
- Resgatar um deck já aprovado, conferir idempotência e isolamento da coleção.
  O novo resgate ficará na conta QA como um resgate normal, salvo decisão
  explícita de restaurar a coleção anterior.
- Criar somente uma sala privada de teste, com UUID e criador registrados,
  incluir adversário/bot e conferir início e seleção de cartas.
- Encerrar e limpar somente a sala/partida criadas por esse teste. Verificar
  ausência dos membros, cartas, eventos e jogadores derivados pelos IDs
  capturados, inclusive após erros de rede.
- Não excluir contas QA, alterar seus nicknames, conceder moderação, modificar
  o autor/deck aprovado ou registrar denúncias reais.

O primeiro resgate pode gerar uma versão aprovada e prévias privadas no
CATALOG. Esse cache legítimo pode ser compartilhado com outros jogadores e
não deve ser removido indiscriminadamente durante a limpeza.

Esse teste com gravações continua pendente; o sucesso de `access` comprova
login e consultas, não comprova resgate ou partida HTTP ponta a ponta.
