# DXA Coleções

App Android (Flutter) com duas seções, escolhidas na tela inicial:

- **Mídia Física:** coleção de jogos com status de cada item, valor pago,
  coleções em abas (ex.: Zelda, Pokémon), progresso por aba e wishlist
  ("Na Fila") com adição em lote a partir da RAWG.
- **LivingDex:** living dex regular e shiny do Pokémon HOME, com formas
  regionais, em lista (ordem da Pokédex) ou em caixas.

Decisões, modelo de dados e roadmap: documento "Projeto Coleção — Modelo de
Dados e Roadmap do MVP".

## O que o app faz (v0.1)

- **Coleção:** lista com capa, busca, filtro por plataforma e status. Abas
  "Todos" + uma por coleção; resumo (itens e progresso) segue a aba.
- **Item:** cadastro manual ou pela busca na RAWG; vínculo de itens já
  existentes; várias coleções por item; Remover da fila (vira Ignorado),
  Restaurar, Excluir.
- **Adição em lote à Wishlist:** por nome ou pela série de um jogo-base,
  filtrando plataformas e anos. Desmarcados viram Ignorado; o que você já
  tem só entra na coleção.
- **Backup e planilha:** backup completo (.json, inclui a LivingDex) e
  restauração; exportação e importação de planilha (.csv).
- **LivingDex:** lista com miniatura colorida (tenho) ou em preto e branco
  (falta), filtros de variante, posse, tipo e jogo de destino; caixas do
  HOME em grade 6 × 5 (15 Pokémon por caixa, regular à esquerda e shiny à
  direita); tela do Pokémon com dados e links para Serebii e Bulbapedia.
- **Carga por print:** prints das caixas do HOME (Switch) escolhidos na
  galeria; cada caixa "Dex X-Y" é reconhecida pelo conteúdo e os espaços
  duvidosos ficam marcados para conferir antes de salvar.

## Configuração (uma vez)

1. Flutter SDK no PATH e Android SDK (Android Studio) com API 36 e NDK.
2. Chave da RAWG em `config/rawg.json` (fora do Git):

   ```json
   {"RAWG_KEY": "sua-chave"}
   ```

3. Dentro desta pasta:

   ```powershell
   flutter create --org com.danix --platforms android .
   flutter pub get
   dart run build_runner build
   ```

   `flutter create .` só adiciona o que falta (pasta `android/` etc.).
   O `build_runner` gera `lib/data/banco.g.dart`; rode de novo sempre que
   mudar as tabelas em `lib/data/banco.dart`.

## Desenvolvimento

```powershell
flutter test
flutter run --dart-define-from-file=config/rawg.json
```

## Gerar o APK

```powershell
flutter build apk --release --dart-define-from-file=config/rawg.json
```

Sai em `build\app\outputs\flutter-apk\app-release.apk`. O APK é assinado
com a chave de debug do computador: instala por cima da versão do
`flutter run` sem apagar os dados. Para publicar na Play Store seria
preciso uma chave própria (e reinstalar, restaurando um backup).

## Estrutura

```
lib/
  main.dart                 App, tema e idioma
  providers.dart            Riverpod: banco, repositório, RAWG e streams
  domain/
    tipos.dart              Status, condição, origem
    regras.dart             Título normalizado, valores, resumo/progresso
    importacao_csv.dart     Leitura do CSV
    exportacao_csv.dart     Geração do CSV
  data/
    banco.dart              Tabelas Drift (schema v6) e migrações
    repositorio.dart        Consultas e operações (Mídia Física)
    repositorio_dex.dart    Consultas e operações (LivingDex)
    rawg.dart               Cliente da API da RAWG
    lote.dart               Candidatos da adição em lote
    backup.dart             Backup JSON e restauração
  livingdex/
    catalogo.dart           Catálogo, caixas, filtros e progresso
    leitor_caixa.dart       Leitura dos prints das caixas do HOME
  ui/                       Telas (livingdex/ para a LivingDex)
assets/
  inicio/                   Imagens da tela inicial
  livingdex/                catalogo.json, miniaturas e modelos.bin (gerados)
tool/livingdex/             Scripts que geram o catálogo e as miniaturas
test/                       Testes (regras, CSV, RAWG, lote, backup, dex)
  fixtures/home/            Prints de caixas do HOME (carga por imagem)
```

O catálogo da LivingDex é gerado uma vez e embutido no app; para atualizar
(novos Pokémon ou formas), rode os scripts de `tool/livingdex/` na ordem
catálogo, miniaturas, modelos, e substitua os arquivos em
`assets/livingdex/`.

Dados e imagens de jogos: [RAWG](https://rawg.io). Dados e imagens de
Pokémon: [PokéAPI](https://pokeapi.co).
