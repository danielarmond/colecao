import 'package:drift/drift.dart';

import '../domain/importacao_csv.dart';
import '../domain/regras.dart';
import '../domain/tipos.dart';
import 'banco.dart';
import 'lote.dart';

/// Um item da coleção com o jogo e a plataforma já resolvidos.
class ItemDetalhado {
  const ItemDetalhado({
    required this.item,
    required this.versao,
    required this.jogo,
    required this.plataforma,
  });

  final ItemColecao item;
  final Versao versao;
  final Jogo jogo;
  final Plataforma plataforma;

  /// Ano na plataforma; se não houver, o ano do jogo.
  int? get ano => versao.anoLancamento ?? jogo.ano;
}

typedef ResultadoLote = ({int naFila, int ignorados, int incluidos});

class ResultadoImportacao {
  const ResultadoImportacao(this.importados, this.duplicados, this.erros);

  final int importados;
  final List<String> duplicados;
  final List<ErroImportacao> erros;
}

class ItemDuplicadoException implements Exception {
  const ItemDuplicadoException(this.titulo, this.plataforma);

  final String titulo;
  final String plataforma;

  @override
  String toString() => '$titulo ($plataforma) já está na sua coleção.';
}

class Repositorio {
  Repositorio(this.db);

  final AppDatabase db;

  // ---------------------------------------------------------------- leitura

  Stream<List<Plataforma>> observarPlataformas() {
    final q = db.select(db.plataformas)
      ..where((p) => p.excluidoEm.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.ordem)]);
    return q.watch();
  }

  Stream<List<Colecao>> observarColecoes() {
    final q = db.select(db.colecoes)
      ..where((c) => c.excluidoEm.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.nome)]);
    return q.watch();
  }

  /// itemId -> ids das coleções em que o item está.
  Stream<Map<String, Set<String>>> observarVinculos() {
    final q = db.select(db.colecoesItens)
      ..where((v) => v.excluidoEm.isNull());
    return q.watch().map((linhas) {
      final mapa = <String, Set<String>>{};
      for (final v in linhas) {
        mapa.putIfAbsent(v.itemId, () => <String>{}).add(v.colecaoId);
      }
      return mapa;
    });
  }

  /// Todos os itens não excluídos, das plataformas mais novas para as mais
  /// antigas, como na planilha. Os filtros são aplicados na tela.
  Stream<List<ItemDetalhado>> observarItens() {
    final q = db.select(db.itensColecao).join([
      innerJoin(db.versoes, db.versoes.id.equalsExp(db.itensColecao.versaoId)),
      innerJoin(db.jogos, db.jogos.id.equalsExp(db.versoes.jogoId)),
      innerJoin(
        db.plataformas,
        db.plataformas.id.equalsExp(db.versoes.plataformaId),
      ),
    ])
      ..where(db.itensColecao.excluidoEm.isNull())
      ..orderBy([
        OrderingTerm.desc(db.plataformas.ordem),
        OrderingTerm.desc(db.versoes.anoLancamento),
        OrderingTerm.asc(db.jogos.titulo),
      ]);

    return q.watch().map(
          (linhas) => [
            for (final l in linhas)
              ItemDetalhado(
                item: l.readTable(db.itensColecao),
                versao: l.readTable(db.versoes),
                jogo: l.readTable(db.jogos),
                plataforma: l.readTable(db.plataformas),
              ),
          ],
        );
  }

  // ---------------------------------------------------------------- escrita

  // -------------------------------------------------------------- coleções

  Future<String> criarColecao(String nome) async {
    final c = await db.into(db.colecoes).insertReturning(
          ColecoesCompanion.insert(nome: nome.trim()),
        );
    return c.id;
  }

  Future<void> renomearColecao(String id, String nome) {
    return (db.update(db.colecoes)..where((c) => c.id.equals(id))).write(
      ColecoesCompanion(
        nome: Value(nome.trim()),
        atualizadoEm: Value(agoraUtc()),
      ),
    );
  }

  /// Exclui a aba. Os itens continuam no app (na aba Todos e nas outras).
  Future<void> excluirColecao(String id) {
    final agora = agoraUtc();
    return db.transaction(() async {
      await (db.update(db.colecoes)..where((c) => c.id.equals(id))).write(
        ColecoesCompanion(excluidoEm: Value(agora), atualizadoEm: Value(agora)),
      );
      await (db.update(db.colecoesItens)
            ..where((v) => v.colecaoId.equals(id) & v.excluidoEm.isNull()))
          .write(
        ColecoesItensCompanion(
          excluidoEm: Value(agora),
          atualizadoEm: Value(agora),
        ),
      );
    });
  }

  /// Coloca o item nas coleções informadas (sem tirar das outras).
  Future<void> incluirEmColecoes(String itemId, Iterable<String> colecaoIds) async {
    for (final colecaoId in colecaoIds) {
      await db.into(db.colecoesItens).insertOnConflictUpdate(
            ColecoesItensCompanion.insert(
              colecaoId: colecaoId,
              itemId: itemId,
              excluidoEm: const Value(null),
              atualizadoEm: Value(agoraUtc()),
            ),
          );
    }
  }

  /// Deixa o item exatamente nas coleções informadas.
  Future<void> definirColecoes(String itemId, Set<String> colecaoIds) {
    return db.transaction(() async {
      final agora = agoraUtc();
      await (db.update(db.colecoesItens)
            ..where(
              (v) =>
                  v.itemId.equals(itemId) &
                  v.excluidoEm.isNull() &
                  v.colecaoId.isNotIn(colecaoIds),
            ))
          .write(
        ColecoesItensCompanion(
          excluidoEm: Value(agora),
          atualizadoEm: Value(agora),
        ),
      );
      await incluirEmColecoes(itemId, colecaoIds);
    });
  }

  Future<void> salvarSemente(String colecaoId, int? rawgId) {
    return (db.update(db.colecoes)..where((c) => c.id.equals(colecaoId)))
        .write(
      ColecoesCompanion(
        rawgJogoSemente: Value(rawgId),
        atualizadoEm: Value(agoraUtc()),
      ),
    );
  }

  /// Adição em lote:
  /// - novos marcados entram como Na Fila nesta coleção;
  /// - novos desmarcados entram como Ignorado nesta coleção (não voltam);
  /// - itens que você já tem só passam a fazer parte desta coleção.
  Future<ResultadoLote> aplicarLote({
    required String colecaoId,
    required List<CandidatoLote> candidatos,
    required Set<String> desmarcados,
    required List<Plataforma> plataformas,
  }) async {
    final porId = {for (final p in plataformas) p.id: p};
    var naFila = 0, ignorados = 0, incluidos = 0;

    for (final c in candidatos) {
      final existente = c.existente;
      if (existente != null) {
        await incluirEmColecoes(existente.itemId, {colecaoId});
        incluidos++;
        continue;
      }
      final plataforma = porId[c.plataforma.id];
      if (plataforma == null) continue;
      final ignorar = desmarcados.contains(c.chave);
      try {
        await adicionarItem(
          titulo: c.jogo.nome,
          plataforma: plataforma,
          ano: c.ano,
          status: ignorar ? StatusItem.ignorado : StatusItem.naFila,
          colecaoIds: {colecaoId},
          rawgId: c.jogo.id,
          capaUrl: c.jogo.capaUrl,
        );
        ignorar ? ignorados++ : naFila++;
      } on ItemDuplicadoException {
        // Já existia sem ter sido reconhecido: não mexe nele.
      }
    }
    return (naFila: naFila, ignorados: ignorados, incluidos: incluidos);
  }

  // ----------------------------------------------------------------- itens

  /// Cadastro. Reaproveita o jogo (pelo id da RAWG ou título) e a versão
  /// (jogo + plataforma) se já existirem. Um item excluído antes é reativado.
  /// Devolve o id do item.
  Future<String> adicionarItem({
    required String titulo,
    required Plataforma plataforma,
    int? ano,
    required StatusItem status,
    int? valorCentavos,
    DateTime? dataChegada,
    Condicao? condicao,
    String? observacoes,
    Set<String> colecaoIds = const {},
    int? rawgId,
    String? capaUrl,
  }) {
    return db.transaction(() async {
      final jogo = await _encontrarOuCriarJogo(
        titulo: titulo,
        ano: ano,
        rawgId: rawgId,
        capaUrl: capaUrl,
      );

      final versao = await (db.select(db.versoes)
                ..where(
                  (v) =>
                      v.jogoId.equals(jogo.id) &
                      v.plataformaId.equals(plataforma.id),
                ))
              .getSingleOrNull() ??
          await db.into(db.versoes).insertReturning(
                VersoesCompanion.insert(
                  jogoId: jogo.id,
                  plataformaId: plataforma.id,
                  anoLancamento: Value(ano),
                ),
              );

      final existente = await (db.select(db.itensColecao)
            ..where((i) => i.versaoId.equals(versao.id)))
          .getSingleOrNull();

      if (existente != null && existente.excluidoEm == null) {
        throw ItemDuplicadoException(jogo.titulo, plataforma.nome);
      }

      final dados = ItensColecaoCompanion(
        status: Value(status),
        valorCentavos: Value(valorCentavos),
        dataChegada: Value(dataChegada),
        condicao: Value(condicao),
        observacoes: Value(_vazioParaNulo(observacoes)),
      );

      final String itemId;
      if (existente != null) {
        itemId = existente.id;
        await (db.update(db.itensColecao)..where((i) => i.id.equals(itemId)))
            .write(
          dados.copyWith(
            excluidoEm: const Value(null),
            atualizadoEm: Value(agoraUtc()),
          ),
        );
      } else {
        final novo = await db.into(db.itensColecao).insertReturning(
              dados.copyWith(versaoId: Value(versao.id)),
            );
        itemId = novo.id;
      }

      await incluirEmColecoes(itemId, colecaoIds);
      return itemId;
    });
  }

  /// Com rawgId: procura pelo id da RAWG. Sem achar, procura pelo título
  /// entre jogos ainda sem vínculo (e vincula). Sem achar, cria.
  Future<Jogo> _encontrarOuCriarJogo({
    required String titulo,
    int? ano,
    int? rawgId,
    String? capaUrl,
  }) async {
    final busca = normalizarTitulo(titulo);

    if (rawgId != null) {
      final porRawg = await (db.select(db.jogos)
            ..where((j) => j.rawgId.equals(rawgId) & j.excluidoEm.isNull())
            ..limit(1))
          .getSingleOrNull();
      if (porRawg != null) return porRawg;
    }

    final porTitulo = await (db.select(db.jogos)
          ..where(
            (j) =>
                j.tituloBusca.equals(busca) &
                j.excluidoEm.isNull() &
                (rawgId == null
                    ? const Constant(true)
                    : j.rawgId.isNull() | j.rawgId.equals(rawgId)),
          )
          ..limit(1))
        .getSingleOrNull();
    if (porTitulo != null) {
      if (rawgId != null && porTitulo.rawgId == null) {
        await _gravarVinculo(porTitulo.id, rawgId, capaUrl);
        return (await (db.select(db.jogos)
                  ..where((j) => j.id.equals(porTitulo.id)))
                .getSingle());
      }
      return porTitulo;
    }

    return db.into(db.jogos).insertReturning(
          JogosCompanion.insert(
            titulo: titulo.trim(),
            tituloBusca: busca,
            ano: Value(ano),
            rawgId: Value(rawgId),
            capaUrl: Value(capaUrl),
            origem: rawgId == null ? OrigemJogo.manual : OrigemJogo.rawg,
          ),
        );
  }

  /// Liga um jogo já cadastrado (ex.: importado da planilha) a um jogo da
  /// RAWG. Mantém o título que você usa; traz o id e a capa.
  Future<void> vincularRawg(String jogoId, int rawgId, String? capaUrl) =>
      _gravarVinculo(jogoId, rawgId, capaUrl);

  Future<void> _gravarVinculo(String jogoId, int rawgId, String? capaUrl) {
    return (db.update(db.jogos)..where((j) => j.id.equals(jogoId))).write(
      JogosCompanion(
        rawgId: Value(rawgId),
        capaUrl: Value(capaUrl),
        origem: const Value(OrigemJogo.rawg),
        atualizadoEm: Value(agoraUtc()),
      ),
    );
  }

  Future<void> atualizarItem(
    ItemDetalhado atual, {
    required int? ano,
    required StatusItem status,
    required int? valorCentavos,
    required DateTime? dataChegada,
    required Condicao? condicao,
    required String? observacoes,
  }) {
    return db.transaction(() async {
      await (db.update(db.itensColecao)
            ..where((i) => i.id.equals(atual.item.id)))
          .write(
        ItensColecaoCompanion(
          status: Value(status),
          valorCentavos: Value(valorCentavos),
          dataChegada: Value(dataChegada),
          condicao: Value(condicao),
          observacoes: Value(_vazioParaNulo(observacoes)),
          atualizadoEm: Value(agoraUtc()),
        ),
      );
      if (ano != atual.versao.anoLancamento) {
        await (db.update(db.versoes)
              ..where((v) => v.id.equals(atual.versao.id)))
            .write(
          VersoesCompanion(
            anoLancamento: Value(ano),
            atualizadoEm: Value(agoraUtc()),
          ),
        );
      }
    });
  }

  /// Usado por "Remover da fila" (vira Ignorado) e "Restaurar" (volta à fila).
  Future<void> mudarStatus(String itemId, StatusItem status) {
    return (db.update(db.itensColecao)..where((i) => i.id.equals(itemId)))
        .write(
      ItensColecaoCompanion(
        status: Value(status),
        atualizadoEm: Value(agoraUtc()),
      ),
    );
  }

  /// Exclusão lógica.
  Future<void> excluirItem(String itemId) {
    final agora = agoraUtc();
    return (db.update(db.itensColecao)..where((i) => i.id.equals(itemId)))
        .write(
      ItensColecaoCompanion(
        excluidoEm: Value(agora),
        atualizadoEm: Value(agora),
      ),
    );
  }

  /// Importa linhas do CSV. Plataforma é procurada pelo nome ou pela sigla;
  /// a coluna "franquia" vira uma coleção (criada se não existir). Itens que
  /// já estão no app são pulados (não sobrescreve nada).
  Future<ResultadoImportacao> importar(List<LinhaImportacao> linhas) async {
    final plataformas = await (db.select(db.plataformas)
          ..where((p) => p.excluidoEm.isNull()))
        .get();
    final porNome = <String, Plataforma>{
      for (final p in plataformas) normalizarTitulo(p.sigla): p,
      for (final p in plataformas) normalizarTitulo(p.nome): p,
    };

    final colecoes = await (db.select(db.colecoes)
          ..where((c) => c.excluidoEm.isNull()))
        .get();
    final colecaoIds = <String, String>{
      for (final c in colecoes) normalizarTitulo(c.nome): c.id,
    };

    var importados = 0;
    final duplicados = <String>[];
    final erros = <ErroImportacao>[];

    for (final l in linhas) {
      final plataforma = porNome[normalizarTitulo(l.plataforma)];
      if (plataforma == null) {
        erros.add(
          ErroImportacao(l.numero, 'plataforma "${l.plataforma}" não existe'),
        );
        continue;
      }

      final ids = <String>{};
      for (final nome in l.colecoes) {
        final chave = normalizarTitulo(nome);
        ids.add(colecaoIds[chave] ??= await criarColecao(nome));
      }

      try {
        await adicionarItem(
          titulo: l.titulo,
          plataforma: plataforma,
          ano: l.ano,
          status: l.status,
          valorCentavos: l.valorCentavos,
          dataChegada: l.dataChegada,
          condicao: l.condicao,
          observacoes: l.observacoes,
          colecaoIds: ids,
          rawgId: l.rawgId,
        );
        importados++;
      } on ItemDuplicadoException {
        duplicados.add('${l.titulo} (${plataforma.sigla})');
      } catch (e) {
        erros.add(ErroImportacao(l.numero, '$e'));
      }
    }
    return ResultadoImportacao(importados, duplicados, erros);
  }

  static String? _vazioParaNulo(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
