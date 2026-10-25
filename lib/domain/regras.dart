import 'tipos.dart';

/// Normaliza um título para busca e para evitar jogos duplicados:
/// minúsculas, sem acentos, sem apóstrofos e sem pontuação.
///
/// "The Legend of Zelda: Link’s Awakening" -> "the legend of zelda links awakening"
String normalizarTitulo(String titulo) {
  const acentos = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final rune in titulo.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    final semAcento = acentos[c] ?? c;
    if (RegExp(r'[a-z0-9]').hasMatch(semAcento)) {
      buffer.write(semAcento);
    } else if (RegExp(r'\s|[-:/&.,]').hasMatch(semAcento)) {
      buffer.write(' ');
    }
    // Apóstrofos e outros símbolos são descartados.
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Nome de exibição a gravar na versão: null quando vazio ou igual ao
/// título do jogo (aí vale o título do jogo, e a versão é a "principal").
String? nomeDeExibicao(String? digitado, String tituloDoJogo) {
  final t = digitado?.trim();
  if (t == null || t.isEmpty) return null;
  if (normalizarTitulo(t) == normalizarTitulo(tituloDoJogo)) return null;
  return t;
}

/// Converte o texto digitado em centavos, arredondando para 2 casas.
///
/// Aceita "117,90", "1.234,56", "117.895" (ponto decimal) e "R$ 50".
/// Retorna null para texto vazio e lança [FormatException] se for inválido.
int? lerValorCentavos(String texto) {
  var t = texto.replaceAll(RegExp(r'[R$\s]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    // Formato brasileiro: ponto é separador de milhar.
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  // Conta com os dígitos em texto, sem ponto flutuante, para que
  // 117.895 vire exatamente 11790 centavos.
  final partes = t.split('.');
  final digitos = RegExp(r'^\d*$');
  if (partes.length > 2 ||
      !partes.every(digitos.hasMatch) ||
      partes.every((p) => p.isEmpty)) {
    throw FormatException('Valor inválido: $texto');
  }
  final inteiro = partes[0].isEmpty ? 0 : int.parse(partes[0]);
  final fracao = partes.length == 2 ? partes[1].padRight(3, '0') : '000';
  var centavos = inteiro * 100 + int.parse(fracao.substring(0, 2));
  if (int.parse(fracao[2]) >= 5) centavos++;
  return centavos;
}

/// "R$ 1.234,56"
String formatarCentavos(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final reais = (abs ~/ 100).toString();
  final cent = (abs % 100).toString().padLeft(2, '0');
  final comMilhar = reais.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return '${negativo ? '-' : ''}R\$ $comMilhar,$cent';
}

/// "117,90" (para preencher o campo de edição)
String centavosParaCampo(int? centavos) {
  if (centavos == null) return '';
  return formatarCentavos(centavos).replaceFirst('R\$ ', '');
}

/// Números do topo da lista. A regra do progresso está no doc do projeto:
/// (Na Coleção + Aguardando) / (Na Coleção + Aguardando + Na Fila).
class ResumoColecao {
  const ResumoColecao({
    required this.naColecao,
    required this.aguardando,
    required this.naFila,
    required this.ignorados,
    required this.gastoCentavos,
  });

  factory ResumoColecao.calcular(
    Iterable<({StatusItem status, int? valorCentavos})> itens,
  ) {
    var naColecao = 0, aguardando = 0, naFila = 0, ignorados = 0, gasto = 0;
    for (final i in itens) {
      switch (i.status) {
        case StatusItem.naColecao:
          naColecao++;
        case StatusItem.aguardando:
          aguardando++;
        case StatusItem.naFila:
          naFila++;
        case StatusItem.ignorado:
          ignorados++;
      }
      if (i.status.ehMeu) gasto += i.valorCentavos ?? 0;
    }
    return ResumoColecao(
      naColecao: naColecao,
      aguardando: aguardando,
      naFila: naFila,
      ignorados: ignorados,
      gastoCentavos: gasto,
    );
  }

  final int naColecao;
  final int aguardando;
  final int naFila;
  final int ignorados;
  final int gastoCentavos;

  int get meus => naColecao + aguardando;
  int get meta => naColecao + aguardando + naFila;

  /// Entre 0 e 1, ou null quando não há meta.
  double? get progresso => meta == 0 ? null : meus / meta;
}
