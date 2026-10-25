import 'package:drift/drift.dart';

import '../livingdex/catalogo.dart';
import 'banco.dart';

/// Leitura e gravação da LivingDex.
class RepositorioDex {
  RepositorioDex(this.db);

  final AppDatabase db;

  /// Chaves (ver [chaveDex]) dos Pokémon que você tem.
  Stream<Set<String>> observarTenho() {
    final q = db.select(db.dexRegistros)
      ..where((r) => r.excluidoEm.isNull());
    return q.watch().map(
          (rs) => {for (final r in rs) chaveDex(r.pokemonId, shiny: r.shiny)},
        );
  }

  /// pokemonId -> shiny indisponível (só os que você ajustou).
  Stream<Map<int, bool>> observarAjustes() {
    final q = db.select(db.dexAjustes)..where((a) => a.excluidoEm.isNull());
    return q.watch().map(
          (rs) => {for (final a in rs) a.pokemonId: a.shinyBloqueado},
        );
  }

  Future<void> definirTenho(
    int pokemonId, {
    required bool shiny,
    required bool tenho,
  }) async {
    final agora = agoraUtc();
    final existente = await (db.select(db.dexRegistros)
          ..where((r) => r.pokemonId.equals(pokemonId) & r.shiny.equals(shiny)))
        .getSingleOrNull();
    if (existente == null) {
      if (!tenho) return;
      await db.into(db.dexRegistros).insert(
            DexRegistrosCompanion.insert(pokemonId: pokemonId, shiny: shiny),
          );
      return;
    }
    await (db.update(db.dexRegistros)
          ..where((r) => r.id.equals(existente.id)))
        .write(
      DexRegistrosCompanion(
        excluidoEm: Value(tenho ? null : agora),
        atualizadoEm: Value(agora),
      ),
    );
  }

  /// Aplica várias marcações de uma vez (carga por print), numa transação,
  /// e guarda os espaços que ficaram para validar.
  /// [mudancas]: chave (ver [chaveDex]) -> tenho.
  Future<void> aplicar(
    Map<String, bool> mudancas, {
    List<DexPendenciasCompanion> pendencias = const [],
  }) {
    return db.transaction(() async {
      for (final MapEntry(:key, :value) in mudancas.entries) {
        final shiny = key.endsWith('s');
        final id = int.parse(key.substring(0, key.length - 1));
        await definirTenho(id, shiny: shiny, tenho: value);
      }
      for (final p in pendencias) {
        await db.into(db.dexPendencias).insert(p);
      }
    });
  }

  /// Lista "Aguardando validação", mais antigas primeiro.
  Stream<List<DexPendencia>> observarPendencias() {
    final q = db.select(db.dexPendencias)
      ..where((p) => p.excluidoEm.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.criadoEm)]);
    return q.watch();
  }

  /// Tira da lista; com [pokemonId], marca esse Pokémon como "tenho".
  Future<void> resolverPendencia(
    DexPendencia pendencia, {
    int? pokemonId,
  }) {
    return db.transaction(() async {
      if (pokemonId != null) {
        await definirTenho(pokemonId, shiny: pendencia.shiny, tenho: true);
      }
      final agora = agoraUtc();
      await (db.update(db.dexPendencias)
            ..where((p) => p.id.equals(pendencia.id)))
          .write(
        DexPendenciasCompanion(
          excluidoEm: Value(agora),
          atualizadoEm: Value(agora),
        ),
      );
    });
  }

  /// Grava se o shiny está disponível; [bloqueado] null volta ao catálogo.
  Future<void> definirShinyBloqueado(int pokemonId, bool? bloqueado) async {
    final agora = agoraUtc();
    if (bloqueado == null) {
      await (db.update(db.dexAjustes)
            ..where((a) => a.pokemonId.equals(pokemonId)))
          .write(
        DexAjustesCompanion(
          excluidoEm: Value(agora),
          atualizadoEm: Value(agora),
        ),
      );
      return;
    }
    await db.into(db.dexAjustes).insertOnConflictUpdate(
          DexAjustesCompanion(
            pokemonId: Value(pokemonId),
            shinyBloqueado: Value(bloqueado),
            atualizadoEm: Value(agora),
            excluidoEm: const Value(null),
          ),
        );
  }
}
