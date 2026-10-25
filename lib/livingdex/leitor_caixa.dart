import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'catalogo.dart';

/// Leitura de prints das caixas do Pokémon HOME (Switch, 1280 × 720 ou
/// proporcional). Cada espaço da grade 6 × 5 é recortado e comparado com as
/// "impressões digitais" das miniaturas (assets/livingdex/modelos.bin,
/// geradas por tool/livingdex/gerar_modelos.py com a mesma normalização).

/// Lado da impressão digital (16 × 16 × RGB).
const ladoModelo = 16;
const _tamanhoModelo = ladoModelo * ladoModelo * 3;

/// Cor de fundo da caixa do HOME; o que fica longe dela é o Pokémon.
const _fundo = [245, 248, 240];
const _limiarFundo = 90;

/// Centros das colunas e linhas da grade num print de 1280 × 720, e a meia
/// largura/altura de cada espaço.
const _centrosX = [94, 187, 278, 369, 461, 554];
const _centrosY = [164, 242, 316, 394, 468];
const _meiaLargura = 46;
const _meiaAltura = 38;

/// Distância acima da qual o espaço é marcado para você conferir.
const limiarConfira = 25.0;

/// Caixa reconhecida quando a melhor pontuação fica abaixo deste valor e
/// bem à frente da segunda colocada.
const _limiarCaixa = 20.0;
const _margemCaixa = 10.0;

class ModelosDex {
  ModelosDex(this.catalogo, this.dados)
      : _indice = {
          for (final (i, p) in catalogo.pokemon.indexed) p.id: i,
        } {
    if (dados.length != catalogo.pokemon.length * 2 * _tamanhoModelo) {
      throw ArgumentError('modelos.bin não corresponde ao catálogo');
    }
  }

  final CatalogoDex catalogo;
  final Uint8List dados;
  final Map<int, int> _indice;

  double distancia(Uint8List v, PokemonDex p, {required bool shiny}) {
    final inicio = (_indice[p.id]! * 2 + (shiny ? 1 : 0)) * _tamanhoModelo;
    var soma = 0;
    for (var k = 0; k < _tamanhoModelo; k++) {
      final d = v[k] - dados[inicio + k];
      soma += d < 0 ? -d : d;
    }
    return soma / _tamanhoModelo;
  }
}

/// Decodifica o arquivo e devolve os 30 espaços, da esquerda para a direita
/// e de cima para baixo: a impressão digital do ícone ou null se vazio.
/// Devolve null se a imagem não tiver a proporção de um print do Switch.
List<Uint8List?>? lerCelulas(Uint8List arquivo) {
  final decodificada = img.decodeImage(arquivo);
  if (decodificada == null) return null;
  final w = decodificada.width;
  final h = decodificada.height;
  if ((w / h - 16 / 9).abs() > 0.05) return null;
  final rgb = decodificada
      .convert(numChannels: 3, format: img.Format.uint8)
      .getBytes(order: img.ChannelOrder.rgb);
  final escala = w / 1280;

  final celulas = <Uint8List?>[];
  for (final cy in _centrosY) {
    for (final cx in _centrosX) {
      final x0 = ((cx - _meiaLargura) * escala).round();
      final x1 = ((cx + _meiaLargura) * escala).round();
      final y0 = ((cy - _meiaAltura) * escala).round();
      final y1 = ((cy + _meiaAltura) * escala).round();
      celulas.add(
        _normalizar(rgb, w, x0, y0, x1, y1, minimo: 100 * escala * escala),
      );
    }
  }
  return celulas;
}

/// Mesmo algoritmo de tool/livingdex/gerar_modelos.py: recorta no contorno,
/// troca o fundo, centraliza num quadrado e tira a média por blocos.
Uint8List? _normalizar(
  Uint8List rgb,
  int largura,
  int x0,
  int y0,
  int x1,
  int y1, {
  required double minimo,
}) {
  final w = x1 - x0;
  final h = y1 - y0;
  final mascara = List<bool>.filled(w * h, false);
  var n = 0;
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = ((y0 + y) * largura + (x0 + x)) * 3;
      final d = (rgb[o] - _fundo[0]).abs() +
          (rgb[o + 1] - _fundo[1]).abs() +
          (rgb[o + 2] - _fundo[2]).abs();
      if (d > _limiarFundo) {
        mascara[y * w + x] = true;
        n++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (n < minimo) return null;

  final cw = maxX - minX + 1;
  final ch = maxY - minY + 1;
  final s = cw > ch ? cw : ch;
  final ox = (s - cw) ~/ 2;
  final oy = (s - ch) ~/ 2;

  // Cor de um ponto do quadrado (fundo fora do recorte e fora da máscara).
  int canal(int qx, int qy, int c) {
    final x = qx - ox;
    final y = qy - oy;
    if (x < 0 || y < 0 || x >= cw || y >= ch) return _fundo[c];
    final mx = minX + x;
    final my = minY + y;
    if (!mascara[my * w + mx]) return _fundo[c];
    return rgb[((y0 + my) * largura + (x0 + mx)) * 3 + c];
  }

  final saida = Uint8List(_tamanhoModelo);
  for (var i = 0; i < ladoModelo; i++) {
    final a = i * s ~/ ladoModelo;
    var b = (i + 1) * s ~/ ladoModelo;
    if (b <= a) b = a + 1;
    for (var j = 0; j < ladoModelo; j++) {
      final e = j * s ~/ ladoModelo;
      var f = (j + 1) * s ~/ ladoModelo;
      if (f <= e) f = e + 1;
      for (var c = 0; c < 3; c++) {
        var soma = 0;
        for (var qy = a; qy < b; qy++) {
          for (var qx = e; qx < f; qx++) {
            soma += canal(qx, qy, c);
          }
        }
        final media = soma / ((b - a) * (f - e));
        saida[(i * ladoModelo + j) * 3 + c] =
            (media + 0.5).floor().clamp(0, 255).toInt();
      }
    }
  }
  return saida;
}

enum TipoLeitura {
  /// Caixa "Dex X-Y" reconhecida pelo conteúdo.
  caixaDex,

  /// Caixa de formas (regionais e as que mudam o tipo): cada ícone
  /// identificado entre as formas.
  regionais,

  /// Não reconhecida (ex.: caixa temporária).
  desconhecida,
}

class EspacoLido {
  EspacoLido({
    required this.ocupado,
    required this.shiny,
    this.pokemon,
    this.distancia,
  }) : temImagem = ocupado;

  /// O print tinha um ícone neste espaço.
  final bool temImagem;

  /// Você pode corrigir na revisão.
  bool ocupado;
  final bool shiny;

  /// Pokémon esperado (caixa Dex) ou reconhecido (regionais).
  final PokemonDex? pokemon;
  final double? distancia;

  /// Pokémon que você indicou na revisão, quando não é o [pokemon].
  PokemonDex? escolhido;

  /// Você conferiu este espaço: não fica mais marcado.
  bool confirmado = false;

  /// O que vale para o espaço: a sua escolha ou o lido.
  PokemonDex? get atual => escolhido ?? pokemon;

  bool get confira =>
      ocupado &&
      !confirmado &&
      (atual == null || (escolhido == null && (distancia ?? 0) > limiarConfira));

  /// Vai para "Aguardando validação" ao salvar: tinha imagem e você a
  /// removeu, ou ficou para conferir. Não muda nada na LivingDex.
  bool get pendente => temImagem && (!ocupado || confira);
}

class LeituraCaixa {
  LeituraCaixa({
    required this.tipo,
    required this.espacos,
    this.caixa,
    this.pontuacao,
  });

  final TipoLeitura tipo;

  /// Índice em [CatalogoDex.caixas] quando [tipo] é caixaDex.
  final int? caixa;
  final double? pontuacao;

  /// Sempre 30 espaços.
  final List<EspacoLido> espacos;

  int get ocupados => espacos.where((e) => e.ocupado).length;
  int get paraConferir => espacos.where((e) => e.confira).length;
}

/// Descobre a caixa pelo conteúdo e lê cada espaço. Com [caixaForcada], usa
/// essa caixa (escolhida por você) sem procurar.
LeituraCaixa analisarCaixa(
  List<Uint8List?> celulas,
  ModelosDex modelos, {
  int? caixaForcada,
}) {
  final cat = modelos.catalogo;
  final nacionais = [
    for (final (i, c) in cat.caixas.indexed)
      if (c.pokemon.every((p) => !p.formaExtra)) i,
  ];

  double pontuar(int c) {
    final caixa = cat.caixas[c];
    var total = 0.0;
    var n = 0;
    for (final (k, v) in celulas.indexed) {
      if (v == null) continue;
      n++;
      final i = k ~/ 2;
      total += i >= caixa.pokemon.length
          ? 60
          : modelos.distancia(v, caixa.pokemon[i], shiny: k.isOdd);
    }
    return n == 0 ? double.infinity : total / n;
  }

  LeituraCaixa daCaixa(int c, double pontuacao) {
    final caixa = cat.caixas[c];
    return LeituraCaixa(
      tipo: TipoLeitura.caixaDex,
      caixa: c,
      pontuacao: pontuacao,
      espacos: [
        for (final (k, v) in celulas.indexed)
          () {
            final i = k ~/ 2;
            final p = i < caixa.pokemon.length ? caixa.pokemon[i] : null;
            return EspacoLido(
              ocupado: v != null,
              shiny: k.isOdd,
              pokemon: p,
              distancia: v == null || p == null
                  ? null
                  : modelos.distancia(v, p, shiny: k.isOdd),
            );
          }(),
      ],
    );
  }

  if (caixaForcada != null) {
    return daCaixa(caixaForcada, pontuar(caixaForcada));
  }
  if (celulas.every((v) => v == null)) {
    return LeituraCaixa(
      tipo: TipoLeitura.desconhecida,
      espacos: [
        for (var k = 0; k < 30; k++) EspacoLido(ocupado: false, shiny: k.isOdd),
      ],
    );
  }

  var melhor = -1;
  var p1 = double.infinity;
  var p2 = double.infinity;
  for (final c in nacionais) {
    final p = pontuar(c);
    if (p < p1) {
      p2 = p1;
      p1 = p;
      melhor = c;
    } else if (p < p2) {
      p2 = p;
    }
  }
  if (melhor >= 0 && p1 < _limiarCaixa && p2 - p1 > _margemCaixa) {
    return daCaixa(melhor, p1);
  }

  // Caixa de formas: cada ícone contra todas as formas da variante.
  final espacos = <EspacoLido>[];
  var soma = 0.0;
  var n = 0;
  for (final (k, v) in celulas.indexed) {
    if (v == null) {
      espacos.add(EspacoLido(ocupado: false, shiny: k.isOdd));
      continue;
    }
    PokemonDex? achado;
    var menor = double.infinity;
    for (final p in cat.formas) {
      final d = modelos.distancia(v, p, shiny: k.isOdd);
      if (d < menor) {
        menor = d;
        achado = p;
      }
    }
    soma += menor;
    n++;
    espacos.add(
      EspacoLido(ocupado: true, shiny: k.isOdd, pokemon: achado, distancia: menor),
    );
  }
  final media = soma / n;
  return LeituraCaixa(
    tipo: media <= limiarConfira ? TipoLeitura.regionais : TipoLeitura.desconhecida,
    pontuacao: media,
    espacos: espacos,
  );
}

/// O que a leitura muda na sua LivingDex: chave (ver [chaveDex]) -> tenho.
/// Caixa Dex: cada espaço da caixa vale (vazio = não tenho); se você
/// indicou outro Pokémon no espaço, ele entra e o esperado fica como falta.
/// Regionais: só acrescenta. "Tenho" vence quando duas leituras discordam.
/// Junta o resultado em [em], se informado.
Map<String, bool> mudancasDaLeitura(LeituraCaixa l, [Map<String, bool>? em]) {
  final m = em ?? <String, bool>{};
  void marcar(PokemonDex p, bool shiny, bool tenho) {
    final k = chaveDex(p.id, shiny: shiny);
    m[k] = (m[k] ?? false) || tenho;
  }

  switch (l.tipo) {
    case TipoLeitura.caixaDex:
      for (final e in l.espacos) {
        if (e.pendente) continue;
        final p = e.pokemon;
        final esc = e.escolhido;
        if (p != null) {
          marcar(p, e.shiny, e.ocupado && (esc == null || esc.id == p.id));
        }
        if (esc != null && esc.id != p?.id && e.ocupado) {
          marcar(esc, e.shiny, true);
        }
      }
    case TipoLeitura.regionais:
      for (final e in l.espacos) {
        if (e.pendente) continue;
        final p = e.atual;
        if (p != null && e.ocupado) marcar(p, e.shiny, true);
      }
    case TipoLeitura.desconhecida:
      break;
  }
  return m;
}

/// Recorte ampliado de um espaço do print (PNG), para a revisão.
Uint8List? recortarEspaco(Uint8List arquivo, int espaco) {
  final im = img.decodeImage(arquivo);
  if (im == null) return null;
  final escala = im.width / 1280;
  final cx = _centrosX[espaco % 6];
  final cy = _centrosY[espaco ~/ 6];
  final x = ((cx - _meiaLargura - 6) * escala).round();
  final y = ((cy - _meiaAltura - 6) * escala).round();
  final w = ((_meiaLargura * 2 + 12) * escala).round();
  final h = ((_meiaAltura * 2 + 12) * escala).round();
  final recorte = img.copyCrop(im, x: x, y: y, width: w, height: h);
  return img.encodePng(
    img.copyResize(
      recorte,
      width: w * 3,
      interpolation: img.Interpolation.linear,
    ),
  );
}

/// Retângulo de cada espaço em frações da imagem (para destacar no print).
({double x, double y, double w, double h}) retanguloEspaco(int espaco) {
  final cx = _centrosX[espaco % 6];
  final cy = _centrosY[espaco ~/ 6];
  return (
    x: (cx - _meiaLargura) / 1280,
    y: (cy - _meiaAltura) / 720,
    w: _meiaLargura * 2 / 1280,
    h: _meiaAltura * 2 / 720,
  );
}
