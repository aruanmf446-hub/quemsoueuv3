# Decks — problemas observados no app (06/11/2026)

## Andamento das correções do cliente

Na branch `work/deck-runtime-corrections`, o commit `a20d1b4` corrige a navegação
do status e o formulário/mensagens de denúncia. Os testes e capturas Web com
backend simulado estão em [evidências](../../evidence/deck-runtime-corrections/README.md).
Isso não confirma uma denúncia real em produção.

O dono definiu DECK-03: resgatar deve **guardar na conta e liberar no Mata-Mata**.
A implementação de resgate e integração GAME/CATALOG está na branch, com
[testes e capturas](../../evidence/community-claims/README.md). Migrations e gateway foram implantados após autorização; o teste HTTP completo
com sessões reais passou em 50/50 verificações, com limpeza conferida. Ver [contrato e ordem de implantação](../backend/DECKS_GAME_CATALOG_INTEGRACAO.md).
O relato original abaixo é preservado como histórico.

> **Natureza:** registro de defeitos e requisitos baseado em três capturas enviadas pelo responsável pelo projeto, feitas no Safari/iPhone em modo horizontal, usando o GitHub Pages. **Não é uma correção implementada nem uma validação do backend.** Nenhum arquivo de gameplay, interface, Supabase ou configuração deve ser alterado por esta documentação.

## Evidências recebidas

| Imagem | Arquivo original | Tela e observação |
| --- | --- | --- |
| **1 — Comunidade** | `IMG_8710.jpeg` | Deck **Trappers**, cinco cartas. Mensagem vermelha **“Não foi possível concluir agora. Tente novamente.”**. O botão **Denunciar** não funciona no uso real relatado. Falta a opção de **Resgatar** para os usuários. |
| **2 — Status correto (referência)** | `IMG_8709.png` | **Status dos decks** mostra o deck Trappers com capa, selo **Em revisão**, explicação, botão **Ver envio** e ação **Atualizar status**. É a apresentação esperada quando o usuário consulta o andamento. |
| **3 — Tela incorreta/intermitente** | `IMG_8708.png` | A consulta ao deck **Trappers** às vezes abre uma tela quase vazia com **“Este deck está em revisão. Para editar, retire-o da Comunidade primeiro.”** e **“Retirar da Comunidade para editar”** no lugar da apresentação completa do status da imagem 2. |

**Arquivos de evidência:** as três capturas originais foram fornecidas na conversa que abriu este registro. Elas devem ser copiadas, sem alteração, para `docs/decks/capturas/2026-11-06/` com os nomes acima. **Os binários ainda não foram incorporados ao repositório neste commit**, portanto não são apresentados aqui como links que já funcionem.

## DECK-01 — Navegação de status inconsistente (prioridade alta)

**Atual:** o mesmo deck em revisão pode apresentar duas telas distintas: a tela informativa completa (imagem 2) ou apenas a mensagem de bloqueio da edição (imagem 3). A ocorrência é **intermitente**, conforme relato do usuário. Não foi isolada uma causa técnica.

**Esperado:** sempre que o usuário abrir **Status dos decks / acompanhar envio**, mostrar a tela da **imagem 2**, com o estado verdadeiro do servidor, capa, selo, andamento, orientação do próximo passo, **Ver envio** e **Atualizar status**. A mensagem de edição bloqueada deve ficar **apenas no fluxo de editar** e não substituir a tela de acompanhamento. Se houver falha de carregamento, apresentar erro claro e opção de tentar novamente, sem transformar isso em uma página quase vazia.

**Reprodução a confirmar:** entrar em **Meus Decks**, consultar o status de Trappers em revisão, voltar e abrir repetidas vezes (também após recarregar o Pages e retomar a sessão). Comparar a navegação quando a tela 2 aparece com quando a tela 3 aparece; registrar rota, parâmetros, estado de sessão, respostas RPC e logs.

**Aceite:** dez aberturas/reaberturas consecutivas de um envio em revisão mantêm a tela informativa; o fluxo **Editar** continua corretamente protegido durante a revisão; os demais estados (aprovado, reprovado, retirado e falha de conexão) não são rotulados incorretamente.

## DECK-02 — Denunciar não conclui no app (prioridade alta)

**Atual:** na página do deck Trappers da Comunidade (imagem 1), o botão **Denunciar** não executa com sucesso a denúncia no uso relatado. A página mostra o erro genérico **“Não foi possível concluir agora. Tente novamente.”**; ainda é preciso confirmar se essa mensagem foi produzida especificamente pelo envio da denúncia ou por outra ação.

**Esperado:** botão acionável para usuário elegível, com motivo, confirmação, envio ao serviço de denúncia e feedback confiável (**denúncia registrada**, **já denunciado**, **não autorizado**, **erro de rede**, etc.). Não exibir sucesso sem confirmação do backend. Respeitar autenticação, autoria, limitação de denúncias repetidas e regras de moderação.

**Investigação recomendada:** conferir o fluxo em `scripts/decks/deck_library_screen.gd` e `scripts/decks/community_service.gd`, a RPC `qse_deck_report`, a sessão autenticada no Web/iPhone, o retorno HTTP/RPC e os estados de erro. Há **testes locais simulados** com sucesso de denúncia em `tests/community_t27/flow_test.gd`; isso **não comprova** funcionamento da operação real no Pages.

**Aceite:** denúncia válida gera registro confirmado; tentativas repetidas ou não autorizadas explicam o impedimento; nenhum erro é silencioso; tela e botões continuam responsivos após erro.

## DECK-03 — Resgatar decks da Comunidade (requisito funcional)

**Atual:** a tela da Comunidade mostrada na imagem 1 não apresenta ação **Resgatar** para o usuário obter um deck elegível. O botão **“Retirar da Comunidade para editar”** da imagem 3 é uma ação do **autor** e **não equivale a resgatar**.

**Esperado:** adicionar uma ação visível **Resgatar** ou **Resgatar grátis** para decks que as regras do produto permitam resgatar. Ao confirmar o resgate, vincular o benefício/deck à conta do usuário e refletir o novo estado (**Resgatado / Na sua conta**), com proteção contra duplicidade, identificação do criador e feedback de falha. Se o deck **não** for resgatável, não mostrar uma ação que simule resgate.

**Dependência a definir antes de implementar:** quais decks comunitários são elegíveis e se resgatar significa receber uma cópia jogável, adicionar à biblioteca pessoal ou usar o sistema de recompensas existente. O projeto já possui uma ação **RESGATAR GRÁTIS** para decks oficiais em `scripts/decks/deck_library_screen.gd`; avaliar reutilização correta sem presumir que todos os decks de terceiros têm o mesmo contrato.

**Aceite:** elegibilidade é validada no servidor; uma conta elegível consegue resgatar e localizar o deck/benefício no destino definido; resgate repetido não duplica item; tentativa sem autenticação ou sem permissão recebe orientação.

## DECK-04 — Erro genérico na galeria (prioridade média)

**Atual:** texto **“Não foi possível concluir agora. Tente novamente.”** aparece acima das cartas de Trappers (imagem 1), sem identificar a ação que falhou.

**Esperado:** informar qual operação falhou e permitir repetição segura; preservar a visualização das cinco cartas quando os dados já estiverem disponíveis. Conferir respostas e permissões do serviço antes de tratar o erro apenas como visual.

## Observações para a equipe

- Reproduzir primeiro no **GitHub Pages real, Safari/iPhone em landscape**, usando uma conta autorizada e um deck de teste; não confundir a interface testada com provas de operação remota.
- Preservar o funcionamento atual da biblioteca, as imagens das cartas, os demais fluxos de publicação e o sistema de revisão.
- **Este README é somente um backlog de problemas e expectativas.** Nenhuma correção foi aplicada e nenhuma suíte foi reexecutada por este registro.
- Documentação relacionada: [Biblioteca](BIBLIOTECA.md), [API da Biblioteca](../backend/T24_BIBLIOTECA_API.md), [revisão de storage e testes manuais](../backend/DECKS_STORAGE_REVISAO_MANUAL.md).
