# Tarefa 09A — lobby para aprovação visual

Base: `831f4aaa4d1682d9c53eae304a9100d8b0d5c43f`.
Branch: `work/lobby-visual-09a`. Não fazer merge sem aprovação visual.

Implementação real em `main_menu.gd` + `lobby_composition.gd`: mantém os nós e rotas da cena original, troca os estilos ornamentados por superfícies compactas, organiza perfil/carteira, reduz o painel social e amplia o Cowboy. O palco recebe enquadramento próprio do lobby (70,68% da altura projetada), sem modificar modelos, animações ou o enquadramento padrão de Skins. O pedestal e cenário original são preservados. `MenuMusic` usa o barramento `Music` existente, sem stream e sem autoplay; receberá somente a faixa aprovada.

Nenhuma mudança em gameplay, cenas de campanha, serviços, economia, modelos, assets ou migrations. Nenhum acesso ao Supabase remoto. Duelo continua indisponível; saldos desconhecidos continuam `—`, sem valores fictícios.

## Validação

- Godot **4.7.2.stable.official.ed1daf0bf**: 22/22 testes headless (importação, 10 fases, 9 transições, funcional e oito rotas do menu).
- Python: 122 + 37 = **159 testes aprovados**.
- Renderização real OpenGL Compatibility/Mesa llvmpipe via Xvfb, nas resoluções nativas **1920×1080**, **1280×720**, **844×390**; sem redimensionar/compor as capturas depois.
- Capturador verifica dimensões reais, elementos dentro da tela, largura compacta do menu, separação do status, enquadramento do personagem e ausência de música não aprovada.
- `git diff --check` aprovado. Hashes de preservação atualizados somente para os dois scripts existentes alterados pela tarefa; não há exclusões genéricas.
- Aviso de V-Sync não suportado pelo renderizador por software, sem erros de script. Não representa benchmark de desempenho ou teste em dispositivo móvel físico.

## Capturas entregues

- [1920×1080](https://chatgpt.com/library?file_id=libfile_38cdfc9fb4c0819193e16eaeaa00b9a4&account_id=personal)
- [1280×720](https://chatgpt.com/library?file_id=libfile_64b3a4d7bd408191b3f6fa9ff74eeb6b&account_id=personal)
- [844×390](https://chatgpt.com/library?file_id=libfile_c0da877388e4819187ff6722aac8836e&account_id=personal)

As capturas mostram o estado local sem sessão. Não simulam amigos, saldo ou login.

Reprodução com ambiente gráfico (substitua a resolução para cada captura):

```sh
godot --path . --rendering-method gl_compatibility --windowed --resolution 1920x1080 --audio-driver Dummy --script res://tools/godot/capture_lobby.gd -- /tmp/lobby-1920x1080.png 1920x1080
python tools/godot/run_smoke.py --godot godot --output /tmp/lobby-smoke
```

O script de captura é um harness de testes, não é executado pelo jogo. A alteração visual é carregada pelo script do menu em execução normal. Os logs desta pasta registram o estado testado; logs de entregas anteriores foram preservados.
