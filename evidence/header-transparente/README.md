# Header transparente e publicação — 2026-11-09

A main já contém a correção visual pelo PR #119 (`1d97394`): PlayerUI deixa
transparentes os preenchimentos das ações secundárias, inclusive as seis abas
superiores do hero. O contorno dourado da seleção e o foco de teclado permanecem.
Esta entrega preserva aquela implementação e as demais alterações da main.

A publicação daquele commit falhou na etapa deploy por timeout:
https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42534530163
O build havia passado. O limite configurado de 1.200.000 ms era reduzido pela
API do Pages para o máximo de 600.000 ms. O workflow agora respeita esse limite
e repete o mesmo artefato uma única vez se a primeira tentativa falhar. Falha na
segunda tentativa continua reprovando o job; não há publicação declarada sem sucesso.
A URL do environment considera a tentativa que efetivamente publicar.

Validação sobre a main integrada:
- Godot 4.7.2, cena principal real: 90 verificações, zero falhas. Inclui navegação,
  teclado, swipe, autoplay, Novidades e transparência normal/hover/pressed das seis abas.
- Build Web real no Chromium: 1672×941, iPhone UA/DPR3 em 844×390 e 640×360.
  Capturas com fixture local de conta, sem tráfego de produção; nenhuma falha de script.
- Design checker e estrutura YAML/condição/limites da repetição: aprovados.
- Não são testes em Safari/aparelho físico.
