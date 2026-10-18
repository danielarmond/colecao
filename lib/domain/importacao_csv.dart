import 'regras.dart';
import 'tipos.dart';

/// Uma linha do CSV já validada.
class LinhaImportacao {
  const LinhaImportacao({
    required this.numero,
    required this.titulo,
    required this.plataforma,
    required this.status,
    this.ano,
    this.colecoes = const [],
    this.valorCentavos,
    this.dataChegada,
    this.condicao,
    this.observacoes,
    this.rawgId,
  });

  final int numero; // linha no arquivo, para mensagens de erro
  final String titulo;
  final String plataforma;
  final StatusItem status;
  final int? ano;

  /// Coleções (abas). No CSV: coluna "colecao" ou "franquia", várias
  /// separadas por "|".
  final List<String> colecoes;
  final int? valorCentavos;
  final DateTime? dataChegada;
  final Condicao? condicao;
  final String? observacoes;
  final int? rawgId;
}

class ErroImportacao {
  const ErroImportacao(this.numero, this.motivo);

  final int numero;
  final String motivo;

  @override
  String toString() => 'Linha $numero: $motivo';
}

class ResultadoLeitura {
  const ResultadoLeitura(this.linhas, this.erros);

  final List<LinhaImportacao> linhas;
  final List<ErroImportacao> erros;
}

/// Colunas esperadas (cabeçalho do colecao_importacao.csv):
/// titulo, plataforma, ano, franquia, status, valor_pago, data_chegada
/// Só titulo, plataforma e status são obrigatórias.
ResultadoLeitura lerCsvImportacao(String conteudo) {
  final tabela = separarCsv(conteudo);
  if (tabela.isEmpty) {
    return const ResultadoLeitura([], [ErroImportacao(1, 'Arquivo vazio')]);
  }

  final cabecalho = [
    for (final c in tabela.first) normalizarTitulo(c.replaceAll('_', ' ')),
  ];
  int? col(String nome) {
    final i = cabecalho.indexOf(nome);
    return i < 0 ? null : i;
  }

  final cTitulo = col('titulo');
  final cPlataforma = col('plataforma');
  final cStatus = col('status');
  if (cTitulo == null || cPlataforma == null || cStatus == null) {
    return const ResultadoLeitura([], [
      ErroImportacao(
        1,
        'O cabeçalho precisa ter as colunas titulo, plataforma e status',
      ),
    ]);
  }
  final cAno = col('ano');
  // "franquia" (planilha antiga) ou "colecao": vira uma coleção (aba).
  final cFranquia = col('franquia') ?? col('colecao');
  final cValor = col('valor pago') ?? col('valor');
  final cData = col('data chegada') ?? col('data');
  final cCondicao = col('condicao');
  final cObs = col('observacoes');
  final cRawg = col('rawg id');

  final linhas = <LinhaImportacao>[];
  final erros = <ErroImportacao>[];

  for (var i = 1; i < tabela.length; i++) {
    final campos = tabela[i];
    final numero = i + 1;
    String? campo(int? c) {
      if (c == null || c >= campos.length) return null;
      final v = campos[c].trim();
      return v.isEmpty ? null : v;
    }

    if (campos.every((c) => c.trim().isEmpty)) continue; // linha em branco

    final titulo = campo(cTitulo);
    final plataforma = campo(cPlataforma);
    if (titulo == null) {
      erros.add(ErroImportacao(numero, 'sem título'));
      continue;
    }
    if (plataforma == null) {
      erros.add(ErroImportacao(numero, 'sem plataforma ($titulo)'));
      continue;
    }

    final status = lerStatus(campo(cStatus) ?? '');
    if (status == null) {
      erros.add(ErroImportacao(numero, 'status inválido ($titulo)'));
      continue;
    }

    int? ano;
    final anoTexto = campo(cAno);
    if (anoTexto != null) {
      ano = int.tryParse(anoTexto);
      if (ano == null) {
        erros.add(ErroImportacao(numero, 'ano inválido ($titulo)'));
        continue;
      }
    }

    int? valor;
    try {
      valor = lerValorCentavos(campo(cValor) ?? '');
    } on FormatException {
      erros.add(ErroImportacao(numero, 'valor inválido ($titulo)'));
      continue;
    }

    DateTime? data;
    final dataTexto = campo(cData);
    if (dataTexto != null) {
      data = lerData(dataTexto);
      if (data == null) {
        erros.add(ErroImportacao(numero, 'data inválida ($titulo)'));
        continue;
      }
    }

    Condicao? condicao;
    final condicaoTexto = campo(cCondicao);
    if (condicaoTexto != null) {
      final alvo = normalizarTitulo(condicaoTexto);
      condicao = Condicao.values
          .where((c) => normalizarTitulo(c.rotulo) == alvo)
          .firstOrNull;
    }

    linhas.add(
      LinhaImportacao(
        numero: numero,
        titulo: titulo,
        plataforma: plataforma,
        status: status,
        ano: ano,
        colecoes: [
          for (final c in (campo(cFranquia) ?? '').split('|'))
            if (c.trim().isNotEmpty) c.trim(),
        ],
        valorCentavos: valor,
        dataChegada: data,
        condicao: condicao,
        observacoes: campo(cObs),
        rawgId: int.tryParse(campo(cRawg) ?? ''),
      ),
    );
  }
  return ResultadoLeitura(linhas, erros);
}

/// Aceita o código do CSV (na_colecao) ou o rótulo (Na Coleção).
/// "Não Aplicável" da planilha antiga vira Ignorado.
StatusItem? lerStatus(String texto) {
  final t = normalizarTitulo(texto.replaceAll('_', ' '));
  for (final s in StatusItem.values) {
    if (t == normalizarTitulo(s.rotulo)) return s;
  }
  if (t == 'nao aplicavel') return StatusItem.ignorado;
  return null;
}

/// "2026-11-04" ou "04/11/2026".
DateTime? lerData(String texto) {
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(texto);
  final br = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(texto);
  int a, m, d;
  if (iso != null) {
    a = int.parse(iso[1]!);
    m = int.parse(iso[2]!);
    d = int.parse(iso[3]!);
  } else if (br != null) {
    d = int.parse(br[1]!);
    m = int.parse(br[2]!);
    a = int.parse(br[3]!);
  } else {
    return null;
  }
  final data = DateTime(a, m, d);
  // DateTime aceita 31/02 e "rola" para março; isso é data inválida.
  if (data.year != a || data.month != m || data.day != d) return null;
  return data;
}

/// Separa um CSV em linhas e campos. Trata aspas ("a, b"), aspas
/// escapadas ("") e quebras de linha \r\n. Detecta ; como separador
/// quando a primeira linha não tem vírgula (CSV salvo pelo Excel em pt-BR).
List<List<String>> separarCsv(String conteudo) {
  var texto = conteudo;
  if (texto.startsWith('﻿')) texto = texto.substring(1); // BOM
  final primeiraLinha = texto.split('\n').first;
  final sep =
      !primeiraLinha.contains(',') && primeiraLinha.contains(';') ? ';' : ',';

  final linhas = <List<String>>[];
  var campos = <String>[];
  final atual = StringBuffer();
  var entreAspas = false;

  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (entreAspas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          atual.write('"');
          i++;
        } else {
          entreAspas = false;
        }
      } else {
        atual.write(c);
      }
    } else if (c == '"') {
      entreAspas = true;
    } else if (c == sep) {
      campos.add(atual.toString());
      atual.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < texto.length && texto[i + 1] == '\n') i++;
      campos.add(atual.toString());
      atual.clear();
      linhas.add(campos);
      campos = <String>[];
    } else {
      atual.write(c);
    }
  }
  if (atual.isNotEmpty || campos.isNotEmpty) {
    campos.add(atual.toString());
    linhas.add(campos);
  }
  return linhas;
}
