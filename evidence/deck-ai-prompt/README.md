# Prompt manual para IA no criador de decks

O botão **Copiar prompt para IA** fica no topo do editor e da revisão, sem abrir
as opções de capa. Inclui nome, tema e assuntos das cartas atuais. Sem cartas,
o modelo usa `[PERSONAGEM OU CENA]`. A geração é feita na IA escolhida pelo jogador;
o jogo apenas copia texto, sem chamadas de geração ou cobrança.

O modelo segue a direção pedida: 3D cinematográfico, longa-metragem animado,
4K e vertical 9:16. Orienta margem para os recortes existentes 5:7 da Biblioteca
e 16:5 do Duelo; esses formatos do jogo permanecem iguais.

Validação no Godot 4.7.2: fluxo T21 com 51 verificações e zero falhas; capturas
reais em 1672×941 (base padrão), 844×390 e 640×360 (perfil iPhone), todas com
`failures=0`. A revisão agora abre no topo, para deixar a ação acessível.
`python3 tools/player_ui/check_design.py`: OK.

Export Web isolado com fixtures: Chromium, user agent de iPhone, viewport
844×390, DPR 3, permissões de clipboard concedidas pelo teste. Toque no botão
real e leitura da área de transferência confirmaram o texto atualizado e igual
no editor e na revisão. Passaram também as regressões de digitação, apagar,
cursor, descrição multilinha, blur, anexar/substituir/capa e bloqueio por modal.
Não houve erros de scripts/cenas. Todas as requisições externas foram bloqueadas.
O ajuste final de rolagem foi conferido nas capturas nativas. Logs e texto copiado
estão ao lado das capturas. Não foi teste em Safari ou iPhone físico.

Reprodução:

```sh
xvfb-run -a godot --path . --script res://tests/decks_t21/flow_test.gd
xvfb-run -a godot --path . --script res://tests/iphone_deck/capture.gd -- /tmp/capturas 844x390 --iphone
node tests/iphone_deck/web_probe.cjs /pasta/do/site /tmp/prova --assert --prompt
```

As imagens de cartas nas fixtures são assets oficiais existentes, sem geração
nova. Nenhum acesso ou alteração no Supabase.
