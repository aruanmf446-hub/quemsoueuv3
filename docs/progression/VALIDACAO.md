# Validação executada — Tarefa Offline 02

Base de preservação: `943c890519111c83aab3c5bdf85bcb120dc02f72`. Branch de trabalho: `codex/progressao-offline-02`. Os testes abaixo são de regras, contratos, arquivos e componentes de referência; **não são testes de gameplay**.

| Verificação | Resultado |
| --- | --- |
| `python3 -m unittest discover -s tools/progression/tests -v` | 88 testes novos aprovados. |
| `python3 tools/offline/test_validation.py` | 37 testes anteriores aprovados novamente. |
| `python3 -m tools.progression check` | Dez fases, dez personagens, três exemplos v2 válidos e 457 arquivos anteriores preservados, incluindo os 49 da entrega anterior. |
| `python3 tools/offline/validate.py` | Zero erros; os dois avisos anteriores permanecem: runtime legado e ausência de execução Godot. |
| JSON Schema completo nos novos JSONs | Regras, política e três saves sintéticos válidos. |
| Links locais da documentação e `git diff --check` | Válidos. |

As execuções usaram `PYTHONDONTWRITEBYTECODE=1`. A dependência `jsonschema==4.26.0` já estava disponível; não houve instalação ou acesso a serviços remotos.

## Casos cobertos

- Jogador novo, sete heróis e acesso só à fase 1.
- Progresso parcial; fase 1 e fase 9 sem desbloquear El Fuego; fase 10 com dez conclusões e condição final de Malagueta.
- Protagonista El Fuego disponível antes do desbloqueio no lobby; personagem bloqueado/inimigo/chefe recusado como equipamento.
- Tentativa de pular fase, concluir sem iniciar, checkpoint de outra fase, checkpoint desconhecido, repetição e limpeza do checkpoint.
- Save CFG antigo, flags antiga/canônica, equipamento legado, save v1 com `verified=true`, alegações parciais/completas, dono diferente e migração v2 idempotente.
- JSON/CFG corrompido, flags com tipo errado, chaves repetidas, versões futuras, origens conflitantes e checksum alterado.
- Backups byte a byte; diretório/arquivo existente não sobrescrito; quarentena sem progresso novo; backup alterado e interrupção de IO.
- Falta de verificador servidor, prova de outro jogador/fase/tentativa, saída ausente, Malagueta não verificado, tentativa/evidência reutilizada e exceção do verificador.
- Reenvio idêntico, mesmo ID com outro conteúdo/revisão, pedidos concorrentes, conclusão duplicada, persistência/restauração do journal e ledger inconsistente.
- Conflito/rebase com ID novo, conservação do pedido antigo, resposta atrasada, mesma revisão com outro conteúdo, rollback de conclusões e versão de regras desconhecida.
- Cache local não autenticado, abertura de nova sessão sem confiança herdada, progresso offline completo sem concessão online e resposta de outro jogador.
- Mudança em conteúdo fixado por hash e configurações de personagem/migração inválidas.

O relatório resumido está em [VALIDACAO.json](VALIDACAO.json).

## Limites

Godot e Blender não foram executados. Não foram testados cenas, combate, física, câmera, controladores, importação de assets ou gameplay. Não há autenticação/anti-cheat real, evidência real de vitória, banco transacional Supabase, RLS, rede, upload ou implantação nesta tarefa. Os dublês de servidor/transporte apenas exercitam a referência isolada.

A flag antiga continua no runtime preservado. A migração segura foi implementada como ferramenta isolada e não foi aplicada aos saves de jogadores nem conectada ao jogo. O aviso antigo não foi suprimido para aparentar uma integração concluída.
