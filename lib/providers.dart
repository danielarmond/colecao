import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/banco.dart';
import 'data/rawg.dart';
import 'data/repositorio.dart';
import 'data/repositorio_dex.dart';
import 'domain/notas.dart';
import 'livingdex/catalogo.dart';
import 'livingdex/leitor_caixa.dart';

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

/// Escala da sua nota (número ou tier), guardada nas preferências.
final escalaNotaProvider = StreamProvider<EscalaNota>(
  (ref) => ref.watch(repositorioProvider).observarEscalaNota(),
);

/// Capa da aba "Todos".
final capaTodosProvider = StreamProvider<String?>(
  (ref) => ref.watch(repositorioProvider).observarCapaTodos(),
);

// ------------------------------------------------------------- LivingDex

final repositorioDexProvider = Provider<RepositorioDex>(
  (ref) => RepositorioDex(ref.watch(bancoProvider)),
);

/// Catálogo embutido (assets/livingdex/catalogo.json), lido uma vez.
final catalogoDexProvider = FutureProvider<CatalogoDex>((ref) async {
  final texto = await rootBundle.loadString('assets/livingdex/catalogo.json');
  return CatalogoDex.deJson(texto);
});

/// Chaves dos Pokémon que você tem (ver chaveDex).
final dexTenhoProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(repositorioDexProvider).observarTenho(),
);

/// Seus ajustes de shiny disponível ou não.
final dexAjustesProvider = StreamProvider<Map<int, bool>>(
  (ref) => ref.watch(repositorioDexProvider).observarAjustes(),
);

/// Espaços de prints aguardando validação.
final dexPendenciasProvider = StreamProvider<List<DexPendencia>>(
  (ref) => ref.watch(repositorioDexProvider).observarPendencias(),
);

/// Impressões digitais das miniaturas, para a carga por print.
final modelosDexProvider = FutureProvider<ModelosDex>((ref) async {
  final catalogo = await ref.watch(catalogoDexProvider.future);
  final dados = await rootBundle.load('assets/livingdex/modelos.bin');
  return ModelosDex(
    catalogo,
    dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
  );
});
