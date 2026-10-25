import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/tipos.dart';

part 'banco.g.dart';

const _uuid = Uuid();

DateTime agoraUtc() => DateTime.now().toUtc();

// Regras para o sync futuro (ver doc do projeto):
// - chaves UUID geradas no aparelho;
// - criado_em / atualizado_em / excluido_em em toda tabela, em UTC;
// - exclusão lógica (excluido_em preenchido), nunca DELETE.

@DataClassName('Plataforma')
class Plataformas extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get rawgId => integer().nullable()();
  TextColumn get nome => text()();
  TextColumn get sigla => text()();
  TextColumn get fabricante => text()();
  IntColumn get ordem => integer()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Jogo')
class Jogos extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get rawgId => integer().nullable()();
  TextColumn get titulo => text()();
  TextColumn get tituloBusca => text()();
  IntColumn get ano => integer().nullable()();
  TextColumn get capaUrl => text().nullable()();
  TextColumn get capaLocal => text().nullable()();
  TextColumn get origem => textEnum<OrigemJogo>()();

  /// Nota dos usuários da RAWG (0 a 5) e quantos votaram.
  RealColumn get notaComunidade => real().nullable()();
  IntColumn get votosComunidade => integer().nullable()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Um jogo em uma plataforma: a unidade que se coleciona.
/// O mesmo jogo pode ter mais de uma versão na mesma plataforma quando a
/// RAWG junta jogos que você trata como itens separados (ex.: Pokémon
/// Scarlet e Violet). Elas se distinguem pelo nome de exibição ([titulo]).
@DataClassName('Versao')
class Versoes extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get jogoId => text().references(Jogos, #id)();
  TextColumn get plataformaId => text().references(Plataformas, #id)();
  IntColumn get anoLancamento => integer().nullable()();
  TextColumn get capaUrl => text().nullable()();

  /// Nome de exibição. Nulo = usa o título do jogo.
  TextColumn get titulo => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Uma aba da tela inicial (ex.: "Zelda", "Pokémon"). Substitui a antiga
/// tabela de franquias (schema v1).
@DataClassName('Colecao')
class Colecoes extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get nome => text()();

  /// Jogo da RAWG usado como base da série na adição em lote (opcional).
  IntColumn get rawgJogoSemente => integer().nullable()();

  /// Imagem de fundo do resumo da aba (capa de um jogo da coleção).
  TextColumn get capaUrl => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Um item pode estar em várias coleções.
@DataClassName('ColecaoItem')
class ColecoesItens extends Table {
  TextColumn get colecaoId => text().references(Colecoes, #id)();
  TextColumn get itemId => text().references(ItensColecao, #id)();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {colecaoId, itemId};
}

/// Sua relação com uma versão. No máximo um item por versão.
@DataClassName('ItemColecao')
class ItensColecao extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get versaoId => text().references(Versoes, #id).unique()();
  TextColumn get status => textEnum<StatusItem>()();
  IntColumn get valorCentavos => integer().nullable()();

  /// Valor de mercado estimado. Recurso pausado: não aparece no app.
  IntColumn get valorMercadoCentavos => integer().nullable()();

  /// Sua nota, de 0 a 10. Exibida como número ou tier (SS a E), conforme a
  /// preferência.
  IntColumn get nota => integer().nullable()();
  BoolColumn get zerado => boolean().withDefault(const Constant(false))();
  TextColumn get moeda => text().withDefault(const Constant('BRL'))();

  /// Real (Na Coleção) ou prevista (Aguardando).
  DateTimeColumn get dataChegada => dateTime().nullable()();
  TextColumn get condicao => textEnum<Condicao>().nullable()();
  TextColumn get observacoes => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// LivingDex: um Pokémon que você tem, em regular ou shiny. O catálogo
/// (espécies, formas, tipos) vem do arquivo embutido no app, não do banco;
/// [pokemonId] é o id da PokéAPI. Tirar da coleção = exclusão lógica.
@DataClassName('DexRegistro')
class DexRegistros extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  IntColumn get pokemonId => integer()();
  BoolColumn get shiny => boolean()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {pokemonId, shiny},
      ];
}

/// LivingDex: ajustes seus sobre o catálogo (ex.: shiny disponível ou não).
@DataClassName('DexAjuste')
class DexAjustes extends Table {
  IntColumn get pokemonId => integer()();
  BoolColumn get shinyBloqueado => boolean()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {pokemonId};
}

/// LivingDex: espaço de um print que ficou para validar depois (não
/// reconhecido, ou reconhecido e removido na revisão). Guarda o recorte.
/// Não entra no backup.
@DataClassName('DexPendencia')
class DexPendencias extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  BlobColumn get recorte => blob()();
  BoolColumn get shiny => boolean()();

  /// Pokémon que o app sugeriu (esperado na caixa ou reconhecido).
  IntColumn get sugestaoId => integer().nullable()();

  /// De onde veio, ex.: "Dex 796-810 · linha 1, coluna 3".
  TextColumn get origem => text()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Preferências do app (chave/valor). Não entram no backup.
@DataClassName('Preferencia')
class Preferencias extends Table {
  TextColumn get chave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {chave};
}

@DriftDatabase(
  tables: [
    Plataformas,
    Jogos,
    Versoes,
    ItensColecao,
    Colecoes,
    ColecoesItens,
    Preferencias,
    DexRegistros,
    DexAjustes,
    DexPendencias,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'colecao'));

  /// v1: franquias ligadas a jogos. v2: coleções ligadas a itens.
  /// v3: nome de exibição na versão; jogo + plataforma pode se repetir.
  /// v4: capa da coleção e valor de mercado do item.
  /// v5: nota da comunidade, sua nota, zerado e preferências.
  /// v6: LivingDex (registros e ajustes).
  /// v7: LivingDex, lista "Aguardando validação".
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _semearPlataformas();
        },
        onUpgrade: (m, de, para) async {
          if (de < 2) await _migrarFranquiasParaColecoes(m);
          if (de < 3) {
            // Recria a tabela sem a regra "um por jogo e plataforma" e com
            // a coluna nova; os dados são copiados pelo Drift.
            await m.alterTable(
              TableMigration(versoes, newColumns: [versoes.titulo]),
            );
          }
          if (de < 4) {
            await m.addColumn(itensColecao, itensColecao.valorMercadoCentavos);
            // Vindo da v1, a tabela de coleções acabou de ser criada já com
            // a coluna nova; só a v2 e a v3 precisam dela.
            if (de >= 2) await m.addColumn(colecoes, colecoes.capaUrl);
          }
          if (de < 5) {
            await m.addColumn(jogos, jogos.notaComunidade);
            await m.addColumn(jogos, jogos.votosComunidade);
            await m.addColumn(itensColecao, itensColecao.nota);
            await m.addColumn(itensColecao, itensColecao.zerado);
            await m.createTable(preferencias);
          }
          if (de < 6) {
            await m.createTable(dexRegistros);
            await m.createTable(dexAjustes);
          }
          if (de < 7) await m.createTable(dexPendencias);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Cada franquia vira uma coleção (mesmo id e nome). Cada jogo que estava
  /// na franquia leva todos os seus itens (todas as plataformas) para a
  /// coleção. Depois as tabelas antigas são apagadas.
  Future<void> _migrarFranquiasParaColecoes(Migrator m) async {
    await m.createTable(colecoes);
    await m.createTable(colecoesItens);
    await customStatement('''
      INSERT INTO colecoes (id, nome, rawg_jogo_semente, criado_em, atualizado_em, excluido_em)
      SELECT id, nome, rawg_jogo_semente, criado_em, atualizado_em, excluido_em
      FROM franquias
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO colecoes_itens (colecao_id, item_id, criado_em, atualizado_em)
      SELECT fj.franquia_id, i.id, fj.criado_em, fj.atualizado_em
      FROM franquias_jogos fj
      JOIN versoes v ON v.jogo_id = fj.jogo_id
      JOIN itens_colecao i ON i.versao_id = v.id
      WHERE fj.excluido_em IS NULL
    ''');
    await customStatement('DROP TABLE IF EXISTS franquias_jogos');
    await customStatement('DROP TABLE IF EXISTS franquias');
  }

  /// Plataformas iniciais, em ordem cronológica de lançamento.
  /// rawgId nulo = plataforma que não existe na RAWG (ver Etapa 0).
  Future<void> _semearPlataformas() async {
    const lista = <(String nome, String sigla, String fabricante, int? rawg)>[
      ('Atari 2600', '2600', 'Atari', 23),
      ('NES', 'NES', 'Nintendo', 49),
      ('Master System', 'SMS', 'Sega', 74),
      ('Famicom Disk System', 'FDS', 'Nintendo', null),
      ('Mega Drive', 'MD', 'Sega', 167),
      ('Game Boy', 'GB', 'Nintendo', 26),
      ('SNES', 'SNES', 'Nintendo', 79),
      ('Game Gear', 'GG', 'Sega', 77),
      ('CD-i', 'CD-i', 'Philips', null),
      ('PlayStation', 'PS1', 'Sony', 27),
      ('Sega Saturn', 'SAT', 'Sega', 107),
      ('Nintendo 64', 'N64', 'Nintendo', 83),
      ('Game Boy Color', 'GBC', 'Nintendo', 43),
      ('Dreamcast', 'DC', 'Sega', 106),
      ('PlayStation 2', 'PS2', 'Sony', 15),
      ('Game Boy Advance', 'GBA', 'Nintendo', 24),
      ('GameCube', 'GC', 'Nintendo', 105),
      ('Xbox', 'XB', 'Microsoft', 80),
      ('Nintendo DS', 'DS', 'Nintendo', 9),
      ('PSP', 'PSP', 'Sony', 17),
      ('Xbox 360', 'X360', 'Microsoft', 14),
      ('Wii', 'Wii', 'Nintendo', 11),
      ('PlayStation 3', 'PS3', 'Sony', 16),
      ('Nintendo 3DS', '3DS', 'Nintendo', 8),
      ('PS Vita', 'Vita', 'Sony', 19),
      ('Wii U', 'WiiU', 'Nintendo', 10),
      ('PlayStation 4', 'PS4', 'Sony', 18),
      ('Xbox One', 'XONE', 'Microsoft', 1),
      ('Nintendo Switch', 'NSW', 'Nintendo', 7),
      ('PlayStation 5', 'PS5', 'Sony', 187),
      ('Xbox Series X|S', 'XSX', 'Microsoft', 186),
      ('Nintendo Switch 2', 'NS2', 'Nintendo', null),
      ('PC', 'PC', 'PC', 4),
    ];
    await batch((b) {
      b.insertAll(plataformas, [
        for (final (i, p) in lista.indexed)
          PlataformasCompanion.insert(
            nome: p.$1,
            sigla: p.$2,
            fabricante: p.$3,
            ordem: (i + 1) * 10,
            rawgId: Value(p.$4),
          ),
      ]);
    });
  }
}
