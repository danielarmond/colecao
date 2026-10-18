import 'tipos.dart';

/// Uma linha da planilha exportada.
typedef LinhaExportacao = ({
  String titulo,
  String plataforma,
  int? ano,
  List<String> colecoes,
  StatusItem status,
  int? valorCentavos,
  DateTime? dataChegada,
  Condicao? condicao,
  String? observacoes,
  int? rawgId,
});

/// Mesmo formato da importação (colecao_importacao.csv), com colunas extras
/// no fim. Várias coleções vão na mesma célula, separadas por " | ".
/// Abre direto no Google Sheets / Excel e pode ser importado de volta.
String gerarCsvExportacao(Iterable<LinhaExportacao> linhas) {
  final b = StringBuffer()
    ..write('titulo,plataforma,ano,colecao,status,valor_pago,data_chegada,'
        'condicao,observacoes,rawg_id\r\n');
  for (final l in linhas) {
    final campos = [
      l.titulo,
      l.plataforma,
      l.ano?.toString() ?? '',
      l.colecoes.join(' | '),
      l.status.codigo,
      l.valorCentavos == null ? '' : _valor(l.valorCentavos!),
      l.dataChegada == null ? '' : _data(l.dataChegada!),
      l.condicao?.rotulo ?? '',
      l.observacoes ?? '',
      l.rawgId?.toString() ?? '',
    ];
    b
      ..write(campos.map(_escapar).join(','))
      ..write('\r\n');
  }
  return b.toString();
}

/// 11790 -> "117.90" (ponto decimal, como no CSV original).
String _valor(int centavos) =>
    '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';

String _data(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _escapar(String campo) {
  if (campo.contains(RegExp(r'[",\r\n]'))) {
    return '"${campo.replaceAll('"', '""')}"';
  }
  return campo;
}
