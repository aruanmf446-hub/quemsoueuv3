# Denunciar jogador — Godot Web 4.7.2

Capturas reais de uma exportação Web isolada, com perfil e respostas de teste.
Não representam uma denúncia enviada contra uma pessoa real. As chamadas HTTP
reais e a limpeza estão documentadas no [relatório da entrega](../../docs/backend/DENUNCIAS_E_DECKS_ENTREGA.md).

- [Desktop](1672x941_report.png)
- [iPhone UA, 844×390/DPR3](844x390_report.png)
- [iPhone UA, 640×360/DPR3](640x360_report.png)
- [Resultados da interação](results.json)
- [Limpeza e conferência da migration no GAME](production-cleanup.json)

O campo HTML sincroniza com o LineEdit. Falhas preservam o motivo; a confirmação
fecha o formulário apenas após `reported:true`. Todos os tamanhos passaram sem
erros de script. Não houve teste em aparelho físico.
