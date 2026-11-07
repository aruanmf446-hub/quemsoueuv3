# Samba — prévia com preço pendente

A aba Personagens → Emotes mostra a Samba aprovada, com “Ver movimento” e
“Preço a definir”. Compra/resgate permanecem bloqueados; não há preço zero,
produto Samba no GAME, concessão ou cobrança nesta entrega.

As capturas vêm do Godot 4.7.2 exportado para Web e executado no Chromium,
com conta sintética de teste. A dança usa os recursos reais aprovados em
assets/emotes/samba, adaptados aos modelos originais. Não é captura de aparelho
físico nem teste de pagamentos reais. As resoluções iPhone usam UA de iPhone
e DPR 3; as imagens são salvas em pixels CSS.

Reprodução: tests/skin_emotes/samba_preview.gd e samba_web.cjs.
O teste nativo cobre os oito rigs, preservação das proporções, prévia e bloqueio
de compra. O teste Web cobre Cowboy, El Fuego e Halloween nas três resoluções,
miniaturas, toque/clique, reprodução e ausência de tentativa de compra.
Resultados e logs acompanham esta pasta; demais GIFs do movimento aprovado
continuam em evidence/fbx-samba-test.
