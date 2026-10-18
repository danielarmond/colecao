import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/banco.dart';
import 'data/rawg.dart';
import 'data/repositorio.dart';

final rawgProvider = Provider<RawgCliente>((ref) => RawgCliente());

final bancoProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositorioProvider = Provider<Repositorio>(
  (ref) => Repositorio(ref.watch(bancoProvider)),
);

final itensProvider = StreamProvider<List<ItemDetalhado>>(
  (ref) => ref.watch(repositorioProvider).observarItens(),
);

final plataformasProvider = StreamProvider<List<Plataforma>>(
  (ref) => ref.watch(repositorioProvider).observarPlataformas(),
);

final colecoesProvider = StreamProvider<List<Colecao>>(
  (ref) => ref.watch(repositorioProvider).observarColecoes(),
);

/// itemId -> ids das coleções do item.
final vinculosProvider = StreamProvider<Map<String, Set<String>>>(
  (ref) => ref.watch(repositorioProvider).observarVinculos(),
);
