import 'catalogo.dart';

/// Planilha (CSV) da LivingDex: uma linha por Pokémon/forma, com o que você
/// tem em regular e em shiny, a posição na caixa e onde ele aparece nos
/// jogos do Switch. Abre no Google Sheets / Excel.
String gerarCsvDex(
  CatalogoDex catalogo, {
  required Set<String> tenho,
  required Map<int, bool> ajustes,
}) {
  final b = StringBuffer()
    ..write('numero,nome,especie,forma,geracao,tipo_1,tipo_2,regular,'
        'shiny,caixa,posicao_regular,posicao_shiny,');
  b.write(JogoDex.values.map((j) => 'jogo_${j.name}').join(','));
  b.write('\r\n');

  for (final p in catalogo.pokemon) {
    final r = catalogo.posicao(p, shiny: false);
    final s = catalogo.posicao(p, shiny: true);
    final shiny = shinyBloqueado(p, ajustes)
        ? 'indisponivel'
        : tenho.contains(chaveDex(p.id, shiny: true))
            ? 'tenho'
            : 'falta';
    final campos = [
      '${p.dex}',
      p.nome,
      p.especie,
      p.regiao ?? (p.alternativa ? 'forma' : ''),
      '${p.geracao}',
      p.tipos.isNotEmpty ? p.tipos[0] : '',
      p.tipos.length > 1 ? p.tipos[1] : '',
      tenho.contains(chaveDex(p.id, shiny: false)) ? 'tenho' : 'falta',
      shiny,
      r?.nome ?? '',
      r == null ? '' : 'L${r.linha}C${r.coluna}',
      s == null ? '' : 'L${s.linha}C${s.coluna}',
      for (final j in JogoDex.values)
        p.jogos.contains(j)
            ? (p.dexJogos[j] == null ? 'sim' : rotuloDexJogo(j, p.dexJogos[j]!))
            : '',
    ];
    b
      ..write(campos.map(_escapar).join(','))
      ..write('\r\n');
  }
  return b.toString();
}

String _escapar(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}
