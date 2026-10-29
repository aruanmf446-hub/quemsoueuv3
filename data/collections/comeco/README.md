# Coleção Começo

Esta é a pasta padrão do catálogo de personagens. O arquivo `../comeco.json` define a coleção `comeco` e o script `scripts/skins/skins_panel.gd` usa os personagens reais de `services.inventory.entries` para preencher o catálogo.

**Não duplicar nem mover os GLB/FBX atuais:** os caminhos importados continuam sendo controlados pelo inventário e pelas cenas Godot existentes. Novas coleções terão arquivos de dados separados e poderão referenciar os mesmos assets por ID.

Os retratos são gerados a partir de capturas reais em `user://thumbnails` e exibidos com corte de busto apenas nos cartões. A prévia continua usando o modelo 3D verdadeiro.
