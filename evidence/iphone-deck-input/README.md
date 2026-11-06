# Teclado e anexos do criador — 06/11/2026

Godot 4.7.2 oficial, branch `work/iphone-deck-input-fixes`.

## Corrigido

- Quando o perfil ainda carregava ou o campo ficava oculto, `clearRegion`
  removia o elemento HTML **e os callbacks**. Ao reaparecer, o campo podia abrir
  o teclado sem devolver o texto ao Godot. A ponte agora religa os callbacks.
- Entrada, composição, exclusão, envio e fechamento sincronizam o modelo;
  não reescreve o valor HTML a cada eco e preserva o cursor. TextEdit usa textarea.
- Primeira escolha de nickname começa vazia; não sugere o nome do Google.
  Nicknames já confirmados continuam definitivos. Nenhuma alteração no backend.
- Input de arquivo sobre o botão nativo recebe o gesto confiável do navegador,
  usando o seletor padrão do dispositivo. MIME da imagem tem prioridade sobre
  o sufixo do nome. Limites e formatos permanecem PNG/JPEG/WebP, até 12 MiB.
- Campos/seletores de arquivo fora da rolagem, sob modais ou popups são removidos
  da camada HTML. Não cobrem o enquadramento nem outras ações.
- Formulário com controles maiores, dados principais juntos, opções de capa e
  referência recolhidas e Adicionar/Salvar/Revisar fixos no rodapé. A carta nova
  entra em foco depois de confirmar o recorte. Estilos via PlayerUI.
- Enquadramento no iPhone mostra a prévia ativa e mantém Confirmar na tela;
  arraste, pinça e zoom continuam disponíveis. Desktop mantém suas prévias/setas.
- Convite de instalação deixa de cobrir telas internas.

## Validação executada

| Verificação | Resultado |
|---|---|
| Godot Web real, Chromium com UA de iPhone, 844×390 e DPR 3 | Edição/exclusão/cursor, descrição com linhas e blur, adicionar/trocar/capa, modal e convite passaram |
| Guarda de nove modelos de iPhone | 504 verificações, 0 falhas |
| Capturas nativas de formulário/carta/enquadramento | 1672×941, 844×390 e 640×360; 0 falhas de layout |
| Política e escolha de nickname | 41 verificações, 0 falhas |
| Ponte de texto nativa | 0 falhas |
| Editor T21 | 47 verificações, 0 falhas |
| Sync T21 | 25 verificações, 0 falhas |
| Comunidade T27 | 14 verificações, 0 falhas |
| Revisão manual | 25 verificações, 0 falhas |
| PWA/teclado/instalação no Chromium | 31 verificações, 0 falhas |
| PlayerUI e export Web de produção | OK |

O teste Web usa o motor exportado, não apenas o shell. O perfil começa em loading
e depois habilita o nickname para exercitar a perda de callbacks. Os testes de
digitação atualizam os valores efetivos do Godot; os de arquivo importam uma
imagem oficial existente, confirmam o recorte e editam os nomes. Todos os pedidos
externos são bloqueados antes da rede; contas e Storage são fixtures sem Supabase.
O pacote de produção não inclui os scripts de fixture.

**Não houve teste em Safari/iPhone físico.** WebKit não está instalado neste
ambiente. O seletor real do sistema no iOS e o teclado físico precisam ser
confirmados pelo dono depois de fechar/reabrir o PWA publicado. Não foi testado
o upload no Storage de produção nem alterada a permissão de trocar nickname.

## Capturas nativas

| Estado | Desktop | iPhone 844×390 | iPhone 640×360 |
|---|---|---|---|
| Formulário | [imagem](1672x941_form.png) | [imagem](844x390_form.png) | [imagem](640x360_form.png) |
| Carta | [imagem](1672x941_card.png) | [imagem](844x390_card.png) | [imagem](640x360_card.png) |
| Enquadramento | [imagem](1672x941_frame.png) | [imagem](844x390_frame.png) | [imagem](640x360_frame.png) |

Reprodução do Web: atualizar uma cópia isolada existente conforme
`tests/iphone/WEB_VALIDATION.md`, executar `tests/iphone_deck/export_fixture.py`
e depois `node tests/iphone_deck/web_probe.cjs <pasta-pai-do-site> <saída> --assert`.
O preset/main_scene de produção não são modificados. A fixture é gerada pelo
motor e exige a feature de teste no Web.
