import 'dart:io';

import 'package:colecao/livingdex/catalogo.dart';
import 'package:colecao/livingdex/exportacao_dex.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cat = CatalogoDex.deJson(
    File('assets/livingdex/catalogo.json').readAsStringSync(),
  );
  PokemonDex porNome(String n) => cat.pokemon.firstWhere((p) => p.nome == n);

  test('catálogo: 1025 espécies e as formas', () {
    expect(cat.nacionais, hasLength(1025));
    expect(cat.formas, hasLength(62));
    expect(porNome('Rapid Strike Urshifu').tipos, ['Fighting', 'Water']);
    expect(porNome('Rapid Strike Urshifu').shinyBloqueado, isTrue);
    expect(cat.pokemon.where((p) => p.especie == 'Rotom'), hasLength(1));
    expect(cat.nacionais.first.nome, 'Bulbasaur');
    expect(cat.nacionais.last.dex, 1025);
    expect(porNome('Alolan Vulpix').tipos, ['Ice']);
    expect(porNome('Galarian Darmanitan').regiao, 'galar');
  });

  test('toda entrada tem miniatura regular e shiny', () {
    for (final p in cat.pokemon) {
      expect(File(p.miniatura(shiny: false)).existsSync(), isTrue,
          reason: p.nome);
      expect(File(p.miniatura(shiny: true)).existsSync(), isTrue,
          reason: p.nome);
    }
  });

  test('caixas seguem a organização do HOME (15 por caixa)', () {
    expect(cat.caixas.first.nome, 'Dex 1-15');
    expect(cat.caixas, hasLength(69 + 5));
    final c = cat.caixas.firstWhere((c) => c.nome == 'Dex 796-810');
    expect(c.pokemon, hasLength(15));
    expect(cat.caixas.last.nome, 'Formas 5');
  });

  test('posição: Rillaboom regular e shiny lado a lado', () {
    final r = porNome('Rillaboom');
    final reg = cat.posicao(r, shiny: false)!;
    final shi = cat.posicao(r, shiny: true)!;
    expect(reg.nome, 'Dex 811-825');
    expect((reg.linha, reg.coluna), (1, 3));
    expect((shi.linha, shi.coluna), (1, 4));
  });

  test('filtros e progresso', () {
    final pika = porNome('Pikachu');
    final calyrex = porNome('Calyrex');
    final tenho = {chaveDex(pika.id, shiny: false)};

    List<PokemonDex> f(FiltroDex filtro, [Map<int, bool> aj = const {}]) =>
        filtrarDex(cat, filtro, tenho: tenho, ajustes: aj);

    expect(f(const FiltroDex(posse: PosseDex.tenho)), [pika]);
    expect(f(const FiltroDex(busca: '#25')), [pika]);
    expect(f(const FiltroDex(busca: 'pikach')), [pika]);
    expect(f(const FiltroDex(tipo: 'Electric')), contains(pika));
    expect(f(const FiltroDex(jogo: JogoDex.pla)),
        isNot(contains(porNome('Growlithe'))));
    expect(f(const FiltroDex(jogo: JogoDex.pla)),
        contains(porNome('Hisuian Growlithe')));

    // Shiny indisponível fica fora do "falta" e do total.
    expect(calyrex.shinyBloqueado, isTrue);
    expect(f(const FiltroDex(shiny: true, posse: PosseDex.falta)),
        isNot(contains(calyrex)));
    final semAjuste =
        progressoDex(cat, shiny: true, tenho: tenho, ajustes: const {});
    final comAjuste =
        progressoDex(cat, shiny: true, tenho: tenho, ajustes: {calyrex.id: false});
    expect(comAjuste.total, semAjuste.total + 1);

    final reg =
        progressoDex(cat, shiny: false, tenho: tenho, ajustes: const {});
    expect(reg, (tenho: 1, total: 1087));
  });

  test('links do Serebii e da Bulbapedia', () {
    expect(porNome('Pikachu').urlSerebii,
        'https://www.serebii.net/pokemon/pikachu/');
    expect(porNome('Pikachu').urlBulbapedia,
        'https://bulbapedia.bulbagarden.net/wiki/Pikachu_(Pok%C3%A9mon)');
  });

  test('geração, Pokédex dos jogos e estatísticas', () {
    expect(porNome('Bulbasaur').geracao, 1);
    expect(porNome('Pecharunt').geracao, 9);
    expect(porNome('Alolan Vulpix').geracao, 7); // forma: geração da região
    expect(porNome('Hisuian Growlithe').geracao, 8);
    expect(porNome('Paldean Wooper').geracao, 9);
    expect(porNome('Sandy Wormadam').geracao, 4);
    expect(nomeGeracao(4), 'Gen 4 (Sinnoh)');
    expect(porNome('Bloodmoon Ursaluna').dexJogos[JogoDex.sv], 'K196');
    expect(rotuloDexJogo(JogoDex.sv, 'K196'), 'Kitakami #196');
    expect(rotuloDexJogo(JogoDex.swsh, 'A068'), 'Isle of Armor #68');
    expect(porNome('Celebi').jogos, isEmpty);

    final porGen = progressoPorGeracao(cat,
        shiny: false, tenho: const {}, ajustes: const {});
    expect(porGen.values.fold<int>(0, (a, c) => a + c.total), 1087);
    expect(porGen[1]!.total, 151);

    expect(porNome('Mewtwo').lendario, isTrue);
    expect(porNome('Celebi').lendario, isTrue); // mítico
    expect(porNome('Pikachu').lendario, isFalse);
    final semL = progressoPorGeracao(cat,
        shiny: false, tenho: const {}, ajustes: const {}, semLendarios: true);
    expect(semL[1]!.total, 151 - 5); // Articuno, Zapdos, Moltres, Mewtwo, Mew

    final pika = porNome('Pikachu');
    final r = faltamPorJogo(cat,
        shiny: false,
        tenho: {chaveDex(pika.id, shiny: false)},
        ajustes: const {});
    expect(r.faltam, 1086);
    expect(r.emNenhum, greaterThan(0));
    expect(r.porJogo[JogoDex.sv], greaterThan(600));

    expect(
        filtrarDex(cat, const FiltroDex(semLendarios: true),
                tenho: const {}, ajustes: const {})
            .any((p) => p.lendario),
        isFalse);

    final filtrados = filtrarDex(cat, const FiltroDex(geracao: 2),
        tenho: const {}, ajustes: const {});
    expect(filtrados.every((p) => p.geracao == 2), isTrue);
    expect(filtrados.first.nome, 'Chikorita');
  });

  test('planilha da LivingDex', () {
    final csv = gerarCsvDex(cat,
        tenho: {chaveDex(porNome('Bulbasaur').id, shiny: false)},
        ajustes: const {});
    final linhas = csv.split('\r\n');
    expect(linhas.first, startsWith('numero,nome,especie,forma,geracao'));
    expect(linhas[1], startsWith('1,Bulbasaur,Bulbasaur,,1,Grass,Poison,tenho,falta,Dex 1-15,L1C1,L1C2'));
    expect(linhas.where((l) => l.isNotEmpty), hasLength(1088));
  });
}

