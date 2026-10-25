import 'dart:convert';

import 'banco.dart';

/// Backup completo: todas as tabelas, linha a linha, inclusive itens
/// excluídos e ignorados. Restaurar substitui tudo o que está no app.
const formatoBackup = 'colecao-backup';

/// Nomes das tabelas no arquivo, na ordem em que podem ser inseridas
/// (quem é referenciado vem antes de quem referencia).
const tabelasBackup = [
  'plataformas',
  'jogos',
  'versoes',
  'itensColecao',
  'colecoes',
  'colecoesItens',
];

/// Tabelas que entraram depois (v6, LivingDex). Num backup mais antigo
/// elas não existem e ficam vazias ao restaurar.
const tabelasOpcionaisBackup = ['dexRegistros', 'dexAjustes'];

/// Backups a partir desta versão do banco podem ser restaurados. Da v2 em
/// diante só entraram colunas opcionais, que ficam vazias ao restaurar.
const versaoMinimaBackup = 2;

typedef ResumoBackup = ({int itens, int colecoes, int jogos, DateTime? geradoEm});

/// Confere se o JSON é um backup deste app e desta versão do banco.
/// Devolve a mensagem de erro, ou null se estiver tudo certo.
String? validarBackup(Object? json, {required int versaoEsquema}) {
  if (json is! Map<String, dynamic> || json['formato'] != formatoBackup) {
    return 'Este arquivo não é um backup do app Coleção.';
  }
  final versao = json['versaoEsquema'];
  if (versao is! int) return 'Backup sem versão do banco.';
  if (versao > versaoEsquema) {
    return 'Este backup é de uma versão mais nova do app. Atualize o app '
        'antes de restaurar.';
  }
  if (versao < versaoMinimaBackup) {
    return 'Este backup é de uma versão antiga do banco (v$versao) e não '
        'pode ser restaurado nesta versão (v$versaoEsquema).';
  }
  for (final t in tabelasBackup) {
    if (json[t] is! List) return 'Backup incompleto: falta "$t".';
  }
  for (final t in tabelasOpcionaisBackup) {
    if (json[t] != null && json[t] is! List) return 'Backup inválido: "$t".';
  }
  return null;
}

/// Contagens para mostrar antes de restaurar (só itens não excluídos).
ResumoBackup resumirBackup(Map<String, dynamic> json) {
  int ativos(String tabela) => (json[tabela] as List)
      .where((r) => r is Map && r['excluidoEm'] == null)
      .length;
  return (
    itens: ativos('itensColecao'),
    colecoes: ativos('colecoes'),
    jogos: ativos('jogos'),
    geradoEm: DateTime.tryParse('${json['geradoEm']}'),
  );
}

class ServicoBackup {
  ServicoBackup(this.db);

  final AppDatabase db;

  Future<Map<String, dynamic>> gerar() async {
    return {
      'formato': formatoBackup,
      'versaoEsquema': db.schemaVersion,
      'geradoEm': DateTime.now().toUtc().toIso8601String(),
      'plataformas': [
        for (final r in await db.select(db.plataformas).get()) r.toJson(),
      ],
      'jogos': [for (final r in await db.select(db.jogos).get()) r.toJson()],
      'versoes': [
        for (final r in await db.select(db.versoes).get()) r.toJson(),
      ],
      'itensColecao': [
        for (final r in await db.select(db.itensColecao).get()) r.toJson(),
      ],
      'colecoes': [
        for (final r in await db.select(db.colecoes).get()) r.toJson(),
      ],
      'colecoesItens': [
        for (final r in await db.select(db.colecoesItens).get()) r.toJson(),
      ],
      'dexRegistros': [
        for (final r in await db.select(db.dexRegistros).get()) r.toJson(),
      ],
      'dexAjustes': [
        for (final r in await db.select(db.dexAjustes).get()) r.toJson(),
      ],
    };
  }

  /// Arquivo .json legível (com recuo), em UTF-8.
  Future<List<int>> gerarArquivo() async =>
      utf8.encode(const JsonEncoder.withIndent('  ').convert(await gerar()));

  /// Apaga tudo e grava o conteúdo do backup, numa transação: se algo
  /// falhar no meio, os dados de antes continuam como estavam.
  Future<void> restaurar(Map<String, dynamic> json) async {
    final erro = validarBackup(json, versaoEsquema: db.schemaVersion);
    if (erro != null) throw FormatException(erro);

    List<Map<String, dynamic>> linhas(String t) =>
        ((json[t] as List?) ?? const []).cast<Map<String, dynamic>>();

    // Converte tudo antes de apagar: um campo inválido para aqui.
    final plataformas = linhas('plataformas').map(Plataforma.fromJson).toList();
    final jogos = linhas('jogos').map(Jogo.fromJson).toList();
    final versoes = linhas('versoes').map(Versao.fromJson).toList();
    final itens = linhas('itensColecao').map(ItemColecao.fromJson).toList();
    final colecoes = linhas('colecoes').map(Colecao.fromJson).toList();
    final vinculos = linhas('colecoesItens').map(ColecaoItem.fromJson).toList();
    final dex = linhas('dexRegistros').map(DexRegistro.fromJson).toList();
    final ajustes = linhas('dexAjustes').map(DexAjuste.fromJson).toList();

    await db.transaction(() async {
      // Apaga de quem referencia para quem é referenciado.
      await db.delete(db.dexAjustes).go();
      await db.delete(db.dexRegistros).go();
      await db.delete(db.colecoesItens).go();
      await db.delete(db.colecoes).go();
      await db.delete(db.itensColecao).go();
      await db.delete(db.versoes).go();
      await db.delete(db.jogos).go();
      await db.delete(db.plataformas).go();

      await db.batch((b) {
        b.insertAll(db.plataformas, plataformas);
        b.insertAll(db.jogos, jogos);
        b.insertAll(db.versoes, versoes);
        b.insertAll(db.itensColecao, itens);
        b.insertAll(db.colecoes, colecoes);
        b.insertAll(db.colecoesItens, vinculos);
        b.insertAll(db.dexRegistros, dex);
        b.insertAll(db.dexAjustes, ajustes);
      });
    });
  }
}
