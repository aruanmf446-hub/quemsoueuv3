# Status e denúncia de decks

Correções do cliente; nenhuma alteração remota no Supabase nesta etapa.

- Abrir um envio em Meus Decks e voltar de Ver envio mantém a tela de status.
  A ação Editar continua protegida para conteúdo em revisão/publicado.
- A denúncia usa controles nativos no viewport do jogo, com teclado HTML no
  Web móvel. Não dá foco automático ao LineEdit no celular: o IME do motor
  roubava o foco do input HTML durante o toque.
- Erros de negócio retornados por RPC com HTTP 200 mantêm seu código.
  Erros de permissão, repetição e autoria não viram erro de login.
- O formulário preserva o motivo após erro, impede envio simultâneo e só
  confirma o registro com `reported:true`, conforme o contrato versionado.

## Verificação executada — Godot 4.7.2 oficial

| Verificação | Resultado |
| --- | --- |
| HTTPRequest real contra servidor loopback | 9 verificações, 0 falhas |
| Status e modal de denúncia, headless | 33 verificações, 0 falhas |
| Autenticação T18 com transporte simulado | 20 verificações, 0 falhas |
| Separação de conexões Supabase | 15 verificações aprovadas |
| Fluxo Comunidade T27 | 14 verificações, 0 falhas |
| Acompanhamento de envios | 29 verificações, 0 falhas |
| Importação e exportação Web oficial | Concluídas |
| `tools/player_ui/check_design.py` | Aprovado |
| Chromium Web 1672×941 (mouse) | Digitação, erro, nova tentativa e confirmação aprovados |
| Chromium Web 844×390 e 640×360 (perfil iPhone, toque) | Digitação, erro, nova tentativa e confirmação aprovados |

O teste de status cobre dez ciclos consecutivos de abertura, Ver envio e
retorno, além da proteção da ação Editar explícita. As suítes usam contas,
decks e decisões simulados; não acessam os projetos Supabase.

Capturas `*_report.png` vêm do **motor Web exportado**, aberto no Chromium,
com toda requisição externa bloqueada. O teste usa mouse no desktop e toque
com user agent de iPhone e DPR 3 nas janelas móveis. Confere digitação,
impedimento por autoria, preservação do motivo e resposta de sucesso
confirmada pela fixture. Arquivos `*_results.json` registram os casos concluídos.

## Limites e pendências

- Não houve validação no Safari/iPhone físico, login real, denúncia real ou
  resgate real. A fixture de galeria não baixa imagens do Storage.
- A tentativa de capturas nativas com Xvfb expirou; não é apresentada como
  uma suíte gráfica aprovada. As capturas Web são evidências separadas.
- Resgate para a conta e liberação no Mata-Mata ainda dependem da integração
  GAME/CATALOG e do acesso administrativo indisponível no ambiente.
  Ver [estado e trabalho restante](../../docs/backend/DECKS_GAME_CATALOG_INTEGRACAO.md).

## Reproduzir

Com `GODOT` apontando para o binário oficial 4.7.2, execute:

```bash
"$GODOT" --headless --path . --audio-driver Dummy --script res://tests/deck_runtime_corrections/flow.gd
```

Para o teste HTTP, inicie `python3 tests/deck_runtime_corrections/rpc_server.py`
em outro terminal e execute `http_flow.gd` da mesma forma. O servidor só
escuta em `127.0.0.1:18856`; não usa credenciais.

O teste Web usa a cópia isolada preparada por `tests/iphone_deck/export_fixture.py`:

```bash
node tests/deck_runtime_corrections/web_probe.cjs <pasta-pai-do-build> <evidencias>
```

O build deve estar em `<pasta-pai-do-build>/quemsoueuv3/index.html`.
`QSE_PROBE_SIZE=844x390` ou `640x360` seleciona um caso. Fixtures nunca
entram no preset de produção.
