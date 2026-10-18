# Coleção

App Android (Flutter) para acompanhar uma coleção de jogos: status de cada
item, valor pago, coleções em abas (ex.: Zelda, Pokémon), progresso por aba
e wishlist ("Na Fila") com adição em lote a partir da RAWG.

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
- **Backup e planilha:** backup completo (.json) e restauração; exportação e
  importação de planilha (.csv).

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
    banco.dart              Tabelas Drift (schema v2) e migração
    repositorio.dart        Consultas e operações
    rawg.dart               Cliente da API da RAWG
    lote.dart               Candidatos da adição em lote
    backup.dart             Backup JSON e restauração
  ui/                       Telas
test/                       Testes (regras, CSV, RAWG, lote, backup)
```

Dados e imagens de jogos: [RAWG](https://rawg.io).
