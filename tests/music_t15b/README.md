# T15B — integração de músicas

Base: `origin/main` em `e3de674`. Branch: `integration/music-t15b`. Origem da tela, catálogo e seleção: `work/music-t14a` em `f8149af`. Não houve merge da branch antiga: foram aproveitados somente a cena Músicas, seu script/UID, catálogo, rota e as extensões necessárias do player. Configurações T14B recebeu só três linhas para criar o botão Gerenciar músicas; Personagens e gameplay não foram alterados.

## Reproduzir

Godot oficial `4.7.2.stable.official.ed1daf0bf`. Não precisa de MP3. O runner gera um WAV de silêncio e uma capa SVG técnica numa pasta ignorada e os remove ao terminar. Ele recusa sobrescrever uma pasta de fixtures preexistente. Cada comando recebe um `user://` temporário próprio, preservando preferências pessoais.

```sh
DISPLAY=:99 python3 tests/music_t15b/run.py \
  --godot /workspace/.setup/quemsoueuv3/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --capture --output /tmp/qse-t15b-results
```

O display é necessário só para `--capture`; omita a opção para testes headless. O runner preserva os códigos de saída e reprova erros do motor mesmo se o código de saída for zero. Resultados e logs vão ao diretório `--output`; capturas reais ficam em `/tmp/qse-t15b-captures`.

## Cobertura

- 29 verificações do fluxo padrão: 14 faixas pendentes, silêncio, acesso via Configurações/Áudio, cinco categorias, ocultação/seleção em rascunho, salvar, descarte, retorno ao Áudio e abandono do rascunho.
- 43 verificações com modo de teste local do editor, incluindo as anteriores e reprodução real de PCM zerado, anterior/próxima, crossfade, pausa/retomada, persistência e barramento de volume, exclusão de faixas, revogação da autorização temporária, saída/retorno ao menu. As fixtures mantêm `pending` e `enabled=false` durante todo o teste.
- 31 verificações na execução com janela, incluindo capturas e o clique real em Gerenciar músicas.
- Suítes existentes de áudio e Configurações T14B executadas sem substituir seus cenários. A expectativa inicial do teste antigo foi atualizada de catálogo vazio para 14 faixas pendentes, mantendo a exigência de silêncio e zero faixas elegíveis.
- Smoke existente de importação, dez fases, nove transições, teste funcional e menu, incluindo a nova rota `music`.

## Capturas e limitações

`evidence/settings-audio.png`: Configurações T14B com o botão integrado.
`evidence/music-from-settings.png`: tela Músicas aberta pelo menu Configurações, com os metadados reais pendentes.

Capturas do framebuffer Godot usando OpenGL Compatibility/Mesa em Linux, sem montagem. Os testes de áudio validam execução e transporte do motor; silêncio técnico não valida a escuta das 14 músicas. Os MP3 não estavam disponíveis neste checkout, não foram baixados nem commitados. A audição desses arquivos depende de fornecimento/importação local e autorização do operador. Builds Android/Web não foram exportadas.
