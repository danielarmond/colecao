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
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Um jogo em uma plataforma: a unidade que se coleciona.
@DataClassName('Versao')
class Versoes extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get jogoId => text().references(Jogos, #id)();
  TextColumn get plataformaId => text().references(Plataformas, #id)();
  IntColumn get anoLancamento => integer().nullable()();
  TextColumn get capaUrl => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get atualizadoEm => dateTime().clientDefault(agoraUtc)();
  DateTimeColumn get excluidoEm => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {jogoId, plataformaId},
      ];
}

/// Uma aba da tela inicial (ex.: "Zelda", "Pokémon"). Substitui a antiga
/// tabela de franquias (schema v1).
@DataClassName('Colecao')
class Colecoes extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get nome => text()();

  /// Jogo da RAWG usado como base da série na adição em lote (opcional).
  IntColumn get rawgJogoSemente => integer().nullable()();
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

@DriftDatabase(
  tables: [Plataformas, Jogos, Versoes, ItensColecao, Colecoes, ColecoesItens],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'colecao'));

  /// v1: franquias ligadas a jogos. v2: coleções ligadas a itens.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _semearPlataformas();
        },
        onUpgrade: (m, de, para) async {
          if (de < 2) await _migrarFranquiasParaColecoes(m);
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
