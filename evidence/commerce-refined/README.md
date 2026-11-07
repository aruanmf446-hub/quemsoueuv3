# Refinamento visual — sem publicação

Aplica qse-design. Artes de moedas e crédito geradas realmente com image_gen,
registradas em assets/ui/store/README.md; não são imagens de tela completa.
Preços, quantidades, botões, seleção e dados da conta continuam nativos/reais.
O estilo segue centralizado em PlayerUI. Não houve alteração de backend,
ativação de pagamento, mudança de preços, concessão ou cobrança.

A galeria reúne busca/filtros numa linha; no iPhone os três personagens e a
paginação ficam visíveis. Avatar, seletores de variação e prévia de movimento
são preservados. Moedas/créditos têm artes próprias sem novas cenas 3D ativas.

Capturas: Godot 4.7.2 Web real em Chromium com fixtures de transporte somente
nos testes. Resoluções 1672×941, 844×390 e 640×360; as duas últimas usam UA de
iPhone/DPR 3, não aparelho físico nem Safari. A exportação final não apresentou
erros de scripts/importação. Carteira: 16 verificações; galeria: 19; ambas
sem falhas. Web verifica navegação, limites dos botões, estados desabilitados,
prévia da Samba e variações. Logs acompanham esta pasta.

Aprovação visual do dono continua pendente; as capturas são para revisão.
