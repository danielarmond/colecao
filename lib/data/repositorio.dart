import 'package:drift/drift.dart';

import '../domain/importacao_csv.dart';
import '../domain/notas.dart';
import '../domain/regras.dart';
import '../domain/tipos.dart';
import 'banco.dart';
import 'lote.dart';
import 'rawg.dart';

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

  /// Nome de exibição: o da versão (ex.: "Pokémon Violet") ou o do jogo.
  String get titulo => versao.titulo ?? jogo.titulo;

  /// Capa da versão, se tiver uma própria; senão, a do jogo.
  String? get capaUrl => versao.capaUrl ?? jogo.capaUrl;
}

typedef ResultadoLote = ({int naFila, int ignorados, int incluidos});

/// Resultado de "Atualizar notas da comunidade".
typedef ResultadoNotas = ({
  int total,
  int atualizados,
  int comNota,
  String? erro,
});

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

  /// Capa da aba (fundo do resumo). Null remove.
  Future<void> definirCapaColecao(String id, String? capaUrl) {
    return (db.update(db.colecoes)..where((c) => c.id.equals(id))).write(
      ColecoesCompanion(
        capaUrl: Value(capaUrl),
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
          notaComunidade: c.jogo.nota,
          votosComunidade: c.jogo.votos,
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
    int? valorMercadoCentavos,
    DateTime? dataChegada,
    Condicao? condicao,
    String? observacoes,
    Set<String> colecaoIds = const {},
    int? rawgId,
    String? capaUrl,
    double? notaComunidade,
    int? votosComunidade,
    String? tituloExibicao,
    int? nota,
    bool zerado = false,
  }) {
    return db.transaction(() async {
      final jogo = await _encontrarOuCriarJogo(
        titulo: titulo,
        ano: ano,
        rawgId: rawgId,
        capaUrl: capaUrl,
        notaComunidade: notaComunidade,
        votosComunidade: votosComunidade,
      );

      // Versão "principal" (sem nome próprio) ou a que tem esse nome.
      final nome = nomeDeExibicao(tituloExibicao, jogo.titulo);
      final versao = await (db.select(db.versoes)
                ..where(
                  (v) =>
                      v.jogoId.equals(jogo.id) &
                      v.plataformaId.equals(plataforma.id) &
                      (nome == null ? v.titulo.isNull() : v.titulo.equals(nome)),
                )
                ..limit(1))
              .getSingleOrNull() ??
          await db.into(db.versoes).insertReturning(
                VersoesCompanion.insert(
                  jogoId: jogo.id,
                  plataformaId: plataforma.id,
                  anoLancamento: Value(ano),
                  titulo: Value(nome),
                ),
              );

      final existente = await (db.select(db.itensColecao)
            ..where((i) => i.versaoId.equals(versao.id)))
          .getSingleOrNull();

      if (existente != null && existente.excluidoEm == null) {
        throw ItemDuplicadoException(nome ?? jogo.titulo, plataforma.nome);
      }

      final dados = ItensColecaoCompanion(
        status: Value(status),
        valorCentavos: Value(valorCentavos),
        valorMercadoCentavos: Value(valorMercadoCentavos),
        dataChegada: Value(dataChegada),
        condicao: Value(condicao),
        observacoes: Value(_vazioParaNulo(observacoes)),
        nota: Value(nota),
        zerado: Value(zerado),
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
    double? notaComunidade,
    int? votosComunidade,
  }) async {
    final busca = normalizarTitulo(titulo);

    if (rawgId != null) {
      final porRawg = await (db.select(db.jogos)
            ..where((j) => j.rawgId.equals(rawgId) & j.excluidoEm.isNull())
            ..limit(1))
          .getSingleOrNull();
      if (porRawg != null) {
        if (notaComunidade != null) {
          await gravarNotaComunidade(
            porRawg.id,
            notaComunidade,
            votosComunidade,
          );
        }
        return porRawg;
      }
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
        await _gravarVinculo(
          porTitulo.id,
          rawgId,
          capaUrl,
          notaComunidade,
          votosComunidade,
        );
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
            notaComunidade: Value(notaComunidade),
            votosComunidade: Value(votosComunidade),
            origem: rawgId == null ? OrigemJogo.manual : OrigemJogo.rawg,
          ),
        );
  }

  /// Liga um jogo já cadastrado (ex.: importado da planilha) a um jogo da
  /// RAWG. Mantém o título que você usa; traz o id e a capa.
  Future<void> vincularRawg(
    String jogoId,
    int rawgId,
    String? capaUrl, {
    double? notaComunidade,
    int? votosComunidade,
  }) =>
      _gravarVinculo(jogoId, rawgId, capaUrl, notaComunidade, votosComunidade);

  Future<void> _gravarVinculo(
    String jogoId,
    int rawgId,
    String? capaUrl,
    double? notaComunidade,
    int? votosComunidade,
  ) {
    return (db.update(db.jogos)..where((j) => j.id.equals(jogoId))).write(
      JogosCompanion(
        rawgId: Value(rawgId),
        capaUrl: Value(capaUrl),
        notaComunidade: Value(notaComunidade),
        votosComunidade: Value(votosComunidade),
        origem: const Value(OrigemJogo.rawg),
        atualizadoEm: Value(agoraUtc()),
      ),
    );
  }

  Future<void> gravarNotaComunidade(String jogoId, double? nota, int? votos) {
    return (db.update(db.jogos)..where((j) => j.id.equals(jogoId))).write(
      JogosCompanion(
        notaComunidade: Value(nota),
        votosComunidade: Value(votos),
        atualizadoEm: Value(agoraUtc()),
      ),
    );
  }

  /// Busca na RAWG a nota da comunidade de cada jogo vinculado, um por vez.
  /// Jogos que falharem são pulados; o último erro volta no resultado.
  Future<ResultadoNotas> atualizarNotasComunidade(
    RawgCliente rawg, {
    void Function(int feitos, int total)? progresso,
  }) async {
    final jogos = await (db.select(db.jogos)
          ..where((j) => j.rawgId.isNotNull() & j.excluidoEm.isNull()))
        .get();
    var atualizados = 0;
    var comNota = 0;
    String? erro;
    for (final (i, j) in jogos.indexed) {
      progresso?.call(i, jogos.length);
      try {
        final r = await rawg.detalhes(j.rawgId!);
        await gravarNotaComunidade(j.id, r.nota, r.votos);
        atualizados++;
        if ((r.nota ?? 0) > 0) comNota++;
      } on RawgErro catch (e) {
        // Sem conexão ou jogo removido da RAWG: segue para o próximo.
        erro = e.mensagem;
      } catch (e) {
        erro = '$e';
      }
    }
    progresso?.call(jogos.length, jogos.length);
    return (
      total: jogos.length,
      atualizados: atualizados,
      comNota: comNota,
      erro: erro,
    );
  }

  // ------------------------------------------------------------ preferências

  Stream<EscalaNota> observarEscalaNota() {
    final q = db.select(db.preferencias)
      ..where((p) => p.chave.equals('escala_nota'));
    return q.watchSingleOrNull().map((p) => EscalaNota.deTexto(p?.valor));
  }

  /// Capa da aba "Todos" (URL de uma capa de jogo), nas preferências.
  Stream<String?> observarCapaTodos() {
    final q = db.select(db.preferencias)
      ..where((p) => p.chave.equals('capa_todos'));
    return q.watchSingleOrNull().map((p) => p?.valor);
  }

  Future<void> definirCapaTodos(String? url) async {
    if (url == null) {
      await (db.delete(db.preferencias)
            ..where((p) => p.chave.equals('capa_todos')))
          .go();
      return;
    }
    await db.into(db.preferencias).insertOnConflictUpdate(
          PreferenciasCompanion.insert(chave: 'capa_todos', valor: url),
        );
  }

  Future<void> definirEscalaNota(EscalaNota escala) {
    return db.into(db.preferencias).insertOnConflictUpdate(
          PreferenciasCompanion.insert(chave: 'escala_nota', valor: escala.name),
        );
  }

  Future<void> atualizarItem(
    ItemDetalhado atual, {
    required int? ano,
    required StatusItem status,
    required int? valorCentavos,
    int? valorMercadoCentavos,
    required DateTime? dataChegada,
    required Condicao? condicao,
    required String? observacoes,
    String? tituloExibicao,
    int? nota,
    bool? zerado,
  }) {
    return db.transaction(() async {
      final nome = nomeDeExibicao(tituloExibicao, atual.jogo.titulo);
      if (tituloExibicao != null && nome != atual.versao.titulo) {
        await (db.update(db.versoes)
              ..where((v) => v.id.equals(atual.versao.id)))
            .write(
          VersoesCompanion(titulo: Value(nome), atualizadoEm: Value(agoraUtc())),
        );
      }
      await (db.update(db.itensColecao)
            ..where((i) => i.id.equals(atual.item.id)))
          .write(
        ItensColecaoCompanion(
          status: Value(status),
          valorCentavos: Value(valorCentavos),
          // Recurso pausado: só grava se vier um valor (não apaga o que há).
          valorMercadoCentavos: valorMercadoCentavos == null
              ? const Value.absent()
              : Value(valorMercadoCentavos),
          dataChegada: Value(dataChegada),
          condicao: Value(condicao),
          observacoes: Value(_vazioParaNulo(observacoes)),
          nota: Value(nota),
          zerado: zerado == null ? const Value.absent() : Value(zerado),
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

  /// "Duplicar jogo": nova versão do mesmo jogo na mesma plataforma, com
  /// outro nome de exibição (ex.: Scarlet e Violet, que a RAWG junta).
  /// O item novo herda status e coleções; valor e datas ficam em branco.
  Future<String> duplicarItem(
    ItemDetalhado original, {
    required String nome,
    required Set<String> colecaoIds,
  }) {
    return db.transaction(() async {
      final versao = await db.into(db.versoes).insertReturning(
            VersoesCompanion.insert(
              jogoId: original.jogo.id,
              plataformaId: original.plataforma.id,
              anoLancamento: Value(original.versao.anoLancamento),
              capaUrl: Value(original.versao.capaUrl),
              titulo: Value(nome.trim()),
            ),
          );
      final item = await db.into(db.itensColecao).insertReturning(
            ItensColecaoCompanion.insert(
              versaoId: versao.id,
              status: original.item.status,
            ),
          );
      await incluirEmColecoes(item.id, colecaoIds);
      return item.id;
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
          valorMercadoCentavos: l.valorMercadoCentavos,
          dataChegada: l.dataChegada,
          condicao: l.condicao,
          observacoes: l.observacoes,
          colecaoIds: ids,
          rawgId: l.rawgId,
          // Com id da RAWG, o título do CSV é o nome de exibição: assim
          // "Pokémon Scarlet" e "Pokémon Violet" voltam como dois itens.
          tituloExibicao: l.rawgId != null ? l.titulo : null,
          nota: l.nota,
          zerado: l.zerado,
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
