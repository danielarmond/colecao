import 'dart:convert';

import 'package:http/http.dart' as http;

/// Chave da RAWG, passada na compilação:
///   flutter run --dart-define-from-file=config/rawg.json
/// O arquivo config/rawg.json fica fora do Git (ver .gitignore).
const rawgChave = String.fromEnvironment('RAWG_KEY');

class RawgPlataforma {
  const RawgPlataforma({required this.id, required this.nome, this.ano});

  final int id;
  final String nome;

  /// Ano de lançamento nesta plataforma, quando a RAWG informa.
  final int? ano;
}

class RawgJogo {
  const RawgJogo({
    required this.id,
    required this.nome,
    required this.plataformas,
    this.ano,
    this.capaUrl,
  });

  factory RawgJogo.fromJson(Map<String, dynamic> json) {
    final plataformas = <RawgPlataforma>[];
    for (final p in (json['platforms'] as List?) ?? const []) {
      final mapa = p as Map<String, dynamic>;
      final plat = mapa['platform'] as Map<String, dynamic>?;
      if (plat == null) continue;
      plataformas.add(
        RawgPlataforma(
          id: plat['id'] as int,
          nome: plat['name'] as String? ?? '',
          ano: _ano(mapa['released_at'] as String?),
        ),
      );
    }
    return RawgJogo(
      id: json['id'] as int,
      nome: json['name'] as String? ?? '',
      ano: _ano(json['released'] as String?),
      capaUrl: capaReduzida(json['background_image'] as String?),
      plataformas: plataformas,
    );
  }

  final int id;
  final String nome;
  final int? ano;
  final String? capaUrl;
  final List<RawgPlataforma> plataformas;

  /// Ano nesta plataforma da RAWG; se não houver, o ano geral do jogo.
  int? anoEm(int? rawgPlataformaId) {
    for (final p in plataformas) {
      if (p.id == rawgPlataformaId && p.ano != null) return p.ano;
    }
    return ano;
  }

  static int? _ano(String? data) =>
      (data == null || data.length < 4) ? null : int.tryParse(data.substring(0, 4));
}

/// A RAWG serve imagens grandes; esta URL pede uma versão menor (600x400).
String? capaReduzida(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.contains('/media/crop/') || url.contains('/media/resize/')) {
    return url;
  }
  return url.replaceFirst('/media/', '/media/crop/600/400/');
}

class RawgErro implements Exception {
  const RawgErro(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

class RawgCliente {
  RawgCliente({http.Client? cliente, this.chave = rawgChave})
      : _http = cliente ?? http.Client();

  final http.Client _http;
  final String chave;

  bool get configurado => chave.isNotEmpty;

  /// Busca simples (tela "Buscar na RAWG"): uma página de 20.
  Future<List<RawgJogo>> buscar(String termo) async {
    final json = await _get('/api/games', {
      'search': termo,
      'page_size': '20',
    });
    return _resultados(json);
  }

  /// Busca para a adição em lote: várias páginas de 40, só títulos que
  /// batem com o termo, opcionalmente filtrando por plataformas da RAWG.
  Future<List<RawgJogo>> buscarVarias(
    String termo, {
    Set<int> plataformas = const {},
    int maxPaginas = 3,
  }) async {
    final todos = <RawgJogo>[];
    for (var pagina = 1; pagina <= maxPaginas; pagina++) {
      final json = await _get('/api/games', {
        'search': termo,
        'search_precise': 'true',
        'page_size': '40',
        'page': '$pagina',
        if (plataformas.isNotEmpty) 'platforms': plataformas.join(','),
      });
      todos.addAll(_resultados(json));
      if (json['next'] == null) break;
    }
    return todos;
  }

  /// Outros jogos da mesma série (não inclui o próprio jogo).
  Future<List<RawgJogo>> serie(int rawgId, {int maxPaginas = 3}) async {
    final todos = <RawgJogo>[];
    for (var pagina = 1; pagina <= maxPaginas; pagina++) {
      final json = await _get('/api/games/$rawgId/game-series', {
        'page_size': '40',
        'page': '$pagina',
      });
      todos.addAll(_resultados(json));
      if (json['next'] == null) break;
    }
    return todos;
  }

  Future<RawgJogo> detalhes(int rawgId) async =>
      RawgJogo.fromJson(await _get('/api/games/$rawgId', const {}));

  List<RawgJogo> _resultados(Map<String, dynamic> json) => [
        for (final j in (json['results'] as List?) ?? const [])
          RawgJogo.fromJson(j as Map<String, dynamic>),
      ];

  Future<Map<String, dynamic>> _get(
    String caminho,
    Map<String, String> parametros,
  ) async {
    if (!configurado) {
      throw const RawgErro(
        'Chave da RAWG não configurada. Rode o app com '
        '--dart-define-from-file=config/rawg.json',
      );
    }
    final uri = Uri.https('api.rawg.io', caminho, {
      'key': chave,
      ...parametros,
    });
    final http.Response resposta;
    try {
      resposta = await _http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const RawgErro('Sem conexão com a RAWG. Verifique a internet.');
    }
    if (resposta.statusCode == 401) {
      throw const RawgErro('A RAWG recusou a chave (401).');
    }
    if (resposta.statusCode == 404) {
      throw const RawgErro('Jogo não encontrado na RAWG (404).');
    }
    if (resposta.statusCode != 200) {
      throw RawgErro('A RAWG respondeu com erro ${resposta.statusCode}.');
    }
    return jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
  }
}
