# Release: atualização por evento, QSE Originals e El Fuego oculto

Atualização sem timer de rede ou polling da UI: consulta ao abrir, recuperar
foco/visibilidade/conexão e pelo botão manual. Um salto de cinco minutos no teste
não gerou requisições de versão. A detecção de versão diferente prepara os arquivos,
com reinício explícito e seguro. Dados de sessão e IndexedDB foram preservados.
Teste PWA avançado: 27 verificações, zero falhas. Regressão PWA: 31, zero falhas.

Lado Sombrio: dez artes PNG originais do dono, UUIDs preservados, nomes/descrições
registrados em deck.json; selo OFICIAL + QSE Originals somente nesse deck. Nenhum
asset foi gerado/substituído. Tag aparece no catálogo, destaque e galeria. Nomes
localizados nos seis idiomas; descrições mantidas no português fornecido pelo dono.

El Fuego fica fora da galeria, busca, contagens, setas e prévia direta antes do
desbloqueio da campanha. Volta após o inventário autoritativo confirmar a recompensa.
Nenhuma recompensa foi concedida ficticiamente ou removida de quem já tem.

Testes Godot 4.7.2: QSE Originals/UUID/partida local/ocultação 50; biblioteca 51;
duelo local 87; hero/rotas 69; versão gratuita 16. Todos sem falhas. Catálogos/glyphs:
31.679 verificações, zero falhas (a maioria valida mensagens/caracteres). Scanner
local: 6 decks, 57 cartas, zero problemas; nenhum SQL foi gerado/aplicado.

Build Godot Web 4.7.2 real: 1672×941, 844×390 e 640×360. Nos dois últimos iPhone UA,
DPR3. Conferidos catálogo com badge, galeria e leitor com conteúdo real, El Fuego
bloqueado ausente e desbloqueado selecionável. Contas/desbloqueio são fixtures
locais, com rede externa bloqueada. Capturas em web/, estados de atualização em
updates/. Não representa validação em aparelho físico ou conta real.

check_design.py, check_catalogs.py, check_pwa.py, check_site.py e git diff --check
passaram. O teste de botões de atualização no motor e os detalhes da implementação
base também estão em evidence/pwa-fast-update/ e docs/web/ATUALIZACOES_PWA.md.

Nenhuma alteração em autenticação, saldos, pagamentos ou Supabase. A inclusão
no catálogo de salas online/resgate é autoritativa do backend e não é consequência
automática de subir PNGs; ver docs/decks/QSE_ORIGINALS.md. Não foi alegada partida
online com o novo deck. O processo de atualização ainda depende do download do
pacote alterado e da publicação do Pages; não garante transferência instantânea.
