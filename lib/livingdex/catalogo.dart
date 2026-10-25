import 'dart:convert';

/// Jogos compatíveis com o HOME usados no filtro "pode ir para".
enum JogoDex {
  swsh('Sword/Shield'),
  bdsp('BD/SP'),
  pla('Legends Arceus'),
  sv('Scarlet/Violet'),
  za('Legends Z-A');

  const JogoDex(this.rotulo);
  final String rotulo;

  static JogoDex? deCodigo(String c) {
    for (final j in values) {
      if (j.name == c) return j;
    }
    return null;
  }
}

/// Um Pokémon do catálogo: uma espécie na forma padrão ou uma forma regional.
class PokemonDex {
  const PokemonDex({
    required this.id,
    required this.dex,
    required this.nome,
    required this.especie,
    required this.regiao,
    this.alternativa = false,
    required this.tipos,
    required this.habilidades,
    required this.habilidadeOculta,
    required this.status,
    required this.jogos,
    required this.shinyBloqueado,
  });

  factory PokemonDex.fromJson(Map<String, dynamic> j) => PokemonDex(
        id: j['id'] as int,
        dex: j['dex'] as int,
        nome: j['nome'] as String,
        especie: j['especie'] as String,
        regiao: j['regiao'] as String?,
        alternativa: j['alternativa'] as bool? ?? false,
        tipos: (j['tipos'] as List).cast<String>(),
        habilidades: (j['habilidades'] as List).cast<String>(),
        habilidadeOculta: j['habilidadeOculta'] as String?,
        status: (j['status'] as List).cast<int>(),
        jogos: (j['jogos'] as List)
            .cast<String>()
            .map(JogoDex.deCodigo)
            .whereType<JogoDex>()
            .toSet(),
        shinyBloqueado: j['shinyBloqueado'] as bool? ?? false,
      );

  /// Id da PokéAPI (formas regionais têm ids acima de 10000).
  final int id;

  /// Número na Pokédex nacional.
  final int dex;
  final String nome;
  final String especie;

  /// alola, galar, hisui, paldea ou null (forma padrão).
  final String? regiao;

  /// Forma que muda o tipo (ex.: Rapid Strike Urshifu, Heat Rotom).
  final bool alternativa;
  final List<String> tipos;
  final List<String> habilidades;
  final String? habilidadeOculta;

  /// HP, Attack, Defense, Sp. Atk, Sp. Def, Speed.
  final List<int> status;
  final Set<JogoDex> jogos;

  /// Shiny indisponível segundo o catálogo (você pode ajustar no app).
  final bool shinyBloqueado;

  bool get regional => regiao != null;

  /// Fica nas caixas de formas (regionais e formas que mudam o tipo).
  bool get formaExtra => regional || alternativa;

  String get numero => '#${dex.toString().padLeft(4, '0')}';

  String miniatura({required bool shiny}) =>
      'assets/livingdex/miniaturas/$id${shiny ? 's' : ''}.webp';

  /// Imagem grande (512 px, estilo HOME), baixada sob demanda.
  String imagem({required bool shiny}) =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
      'pokemon/other/home/${shiny ? 'shiny/' : ''}$id.png';

  String get urlSerebii {
    final slug = especie
        .toLowerCase()
        .replaceAll('♀', 'f')
        .replaceAll('♂', 'm')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'https://www.serebii.net/pokemon/$slug/';
  }

  String get urlBulbapedia =>
      'https://bulbapedia.bulbagarden.net/wiki/'
      '${Uri.encodeComponent(especie.replaceAll(' ', '_'))}_(Pok%C3%A9mon)';
}

/// Uma caixa do HOME na organização da sua living dex: 15 Pokémon, cada um
/// ocupando um par de espaços (regular à esquerda, shiny à direita).
class CaixaDex {
  const CaixaDex({required this.nome, required this.pokemon});

  final String nome;

  /// Até 15, em ordem; posição i ocupa os espaços 2i (regular) e 2i+1 (shiny).
  final List<PokemonDex> pokemon;
}

const pokemonPorCaixa = 15;

class CatalogoDex {
  CatalogoDex(this.pokemon)
      : _porId = {for (final p in pokemon) p.id: p},
        nacionais = [for (final p in pokemon) if (!p.formaExtra) p],
        formas = [for (final p in pokemon) if (p.formaExtra) p];

  factory CatalogoDex.deJson(String texto) {
    final j = jsonDecode(texto) as Map<String, dynamic>;
    return CatalogoDex([
      for (final p in (j['pokemon'] as List).cast<Map<String, dynamic>>())
        PokemonDex.fromJson(p),
    ]);
  }

  /// Ordem da lista: nacionais pela Pokédex, depois as formas (regionais e
  /// as que mudam o tipo).
  final List<PokemonDex> pokemon;
  final List<PokemonDex> nacionais;
  final List<PokemonDex> formas;
  final Map<int, PokemonDex> _porId;

  PokemonDex? porId(int id) => _porId[id];

  /// Nacionais em caixas "Dex 1-15", "Dex 16-30"…; formas em "Formas 1",
  /// "Formas 2"…
  late final List<CaixaDex> caixas = [
    for (var i = 0; i < nacionais.length; i += pokemonPorCaixa)
      CaixaDex(
        nome: 'Dex ${nacionais[i].dex}-'
            '${nacionais[_fim(i, nacionais.length) - 1].dex}',
        pokemon: nacionais.sublist(i, _fim(i, nacionais.length)),
      ),
    for (var i = 0; i < formas.length; i += pokemonPorCaixa)
      CaixaDex(
        nome: 'Formas ${i ~/ pokemonPorCaixa + 1}',
        pokemon: formas.sublist(i, _fim(i, formas.length)),
      ),
  ];

  static int _fim(int i, int total) =>
      i + pokemonPorCaixa > total ? total : i + pokemonPorCaixa;

  /// Caixa e espaço (1 a 30) de um Pokémon na variante pedida.
  ({int caixa, String nome, int linha, int coluna})? posicao(
    PokemonDex p, {
    required bool shiny,
  }) {
    for (final (c, caixa) in caixas.indexed) {
      final i = caixa.pokemon.indexOf(p);
      if (i < 0) continue;
      final espaco = i * 2 + (shiny ? 1 : 0);
      return (
        caixa: c,
        nome: caixa.nome,
        linha: espaco ~/ 6 + 1,
        coluna: espaco % 6 + 1,
      );
    }
    return null;
  }

  late final List<String> tipos = () {
    final t = {for (final p in pokemon) ...p.tipos}.toList()..sort();
    return t;
  }();
}

/// Chave de um registro: id + variante.
String chaveDex(int pokemonId, {required bool shiny}) =>
    '$pokemonId${shiny ? 's' : 'r'}';

enum PosseDex { todos, tenho, falta }

/// Filtros da lista da LivingDex.
class FiltroDex {
  const FiltroDex({
    this.shiny = false,
    this.posse = PosseDex.todos,
    this.tipo,
    this.jogo,
    this.busca = '',
  });

  final bool shiny;
  final PosseDex posse;
  final String? tipo;
  final JogoDex? jogo;
  final String busca;

  FiltroDex copiar({
    bool? shiny,
    PosseDex? posse,
    String? Function()? tipo,
    JogoDex? Function()? jogo,
    String? busca,
  }) =>
      FiltroDex(
        shiny: shiny ?? this.shiny,
        posse: posse ?? this.posse,
        tipo: tipo == null ? this.tipo : tipo(),
        jogo: jogo == null ? this.jogo : jogo(),
        busca: busca ?? this.busca,
      );
}

/// Shiny indisponível: o ajuste seu vence o catálogo.
bool shinyBloqueado(PokemonDex p, Map<int, bool> ajustes) =>
    ajustes[p.id] ?? p.shinyBloqueado;

List<PokemonDex> filtrarDex(
  CatalogoDex catalogo,
  FiltroDex f, {
  required Set<String> tenho,
  required Map<int, bool> ajustes,
}) {
  final busca = f.busca.trim().toLowerCase();
  final numero = int.tryParse(busca.replaceAll('#', ''));
  return [
    for (final p in catalogo.pokemon)
      if ((f.tipo == null || p.tipos.contains(f.tipo)) &&
          (f.jogo == null || p.jogos.contains(f.jogo)) &&
          (busca.isEmpty ||
              (numero != null
                  ? p.dex == numero
                  : p.nome.toLowerCase().contains(busca))) &&
          switch (f.posse) {
            PosseDex.todos => true,
            PosseDex.tenho => tenho.contains(chaveDex(p.id, shiny: f.shiny)),
            PosseDex.falta => !tenho.contains(chaveDex(p.id, shiny: f.shiny)) &&
                !(f.shiny && shinyBloqueado(p, ajustes)),
          })
        p,
  ];
}

/// Progresso de uma variante: quantos você tem entre os disponíveis.
({int tenho, int total}) progressoDex(
  CatalogoDex catalogo, {
  required bool shiny,
  required Set<String> tenho,
  required Map<int, bool> ajustes,
}) {
  var total = 0;
  var meus = 0;
  for (final p in catalogo.pokemon) {
    if (shiny && shinyBloqueado(p, ajustes)) continue;
    total++;
    if (tenho.contains(chaveDex(p.id, shiny: shiny))) meus++;
  }
  return (tenho: meus, total: total);
}
