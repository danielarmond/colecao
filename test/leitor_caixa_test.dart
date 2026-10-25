import 'dart:io';

import 'package:colecao/livingdex/catalogo.dart';
import 'package:colecao/livingdex/leitor_caixa.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prints reais das caixas do HOME (test/fixtures/home), com a caixa e
/// quantos espaços estão ocupados em cada um.
const _prints = [
  ('caixa_01.jpg', 'Dex 796-810', 17),
  ('caixa_02.jpg', 'Dex 811-825', 22),
  ('caixa_03.jpg', 'Dex 826-840', 23),
  ('caixa_04.jpg', 'Dex 841-855', 23),
  ('caixa_05.jpg', 'Dex 856-870', 23),
  ('caixa_06.jpg', 'Dex 871-885', 21),
  ('caixa_07.jpg', 'Dex 886-900', 19),
  ('caixa_08.jpg', 'Dex 901-915', 28),
];

void main() {
  final cat = CatalogoDex.deJson(
    File('assets/livingdex/catalogo.json').readAsStringSync(),
  );
  final modelos = ModelosDex(
    cat,
    File('assets/livingdex/modelos.bin').readAsBytesSync(),
  );

  for (final (arquivo, caixa, ocupados) in _prints) {
    test('reconhece $caixa', () {
      final celulas =
          lerCelulas(File('test/fixtures/home/$arquivo').readAsBytesSync())!;
      final l = analisarCaixa(celulas, modelos);
      expect(l.tipo, TipoLeitura.caixaDex);
      expect(cat.caixas[l.caixa!].nome, caixa);
      expect(l.ocupados, ocupados);
      expect(l.paraConferir, lessThanOrEqualTo(2));
    });
  }

  test('mudanças: ocupado vira tenho, vazio vira falta', () {
    final celulas = lerCelulas(
      File('test/fixtures/home/caixa_02.jpg').readAsBytesSync(),
    )!;
    final m = mudancasDaLeitura(analisarCaixa(celulas, modelos));
    final rillaboom = cat.pokemon.firstWhere((p) => p.nome == 'Rillaboom');
    final thwackey = cat.pokemon.firstWhere((p) => p.nome == 'Thwackey');
    expect(m[chaveDex(rillaboom.id, shiny: true)], isTrue);
    expect(m[chaveDex(thwackey.id, shiny: false)], isTrue);
    expect(m[chaveDex(thwackey.id, shiny: true)], isFalse);
    expect(m, hasLength(30));
  });

  test('Pokémon indicado na revisão entra no lugar do esperado', () {
    final celulas = lerCelulas(
      File('test/fixtures/home/caixa_02.jpg').readAsBytesSync(),
    )!;
    final l = analisarCaixa(celulas, modelos);
    final thwackey = cat.pokemon.firstWhere((p) => p.nome == 'Thwackey');
    final bulbasaur = cat.pokemon.firstWhere((p) => p.nome == 'Bulbasaur');
    final e = l.espacos[0];
    expect(e.pokemon, thwackey);
    e
      ..escolhido = bulbasaur
      ..confirmado = true;
    expect(e.confira, isFalse);
    final m = mudancasDaLeitura(l);
    expect(m[chaveDex(bulbasaur.id, shiny: false)], isTrue);
    expect(m[chaveDex(thwackey.id, shiny: false)], isFalse);
  });

  test('removido ou não conferido vai para validação e não muda nada', () {
    final l = analisarCaixa(
      lerCelulas(File('test/fixtures/home/caixa_02.jpg').readAsBytesSync())!,
      modelos,
    );
    final thwackey = l.espacos[0].pokemon!;
    l.espacos[0]
      ..ocupado = false
      ..confirmado = true;
    expect(l.espacos[0].pendente, isTrue);
    final m = mudancasDaLeitura(l);
    expect(m.containsKey(chaveDex(thwackey.id, shiny: false)), isFalse);
    expect(m, hasLength(29));

    // Espaço marcado para conferir e não conferido também fica pendente.
    final l1 = analisarCaixa(
      lerCelulas(File('test/fixtures/home/caixa_01.jpg').readAsBytesSync())!,
      modelos,
    );
    final duvidosos = l1.espacos.where((e) => e.confira).toList();
    expect(duvidosos, isNotEmpty);
    expect(duvidosos.every((e) => e.pendente), isTrue);
  });

  test('caixa escolhida à mão', () {
    final celulas = lerCelulas(
      File('test/fixtures/home/caixa_02.jpg').readAsBytesSync(),
    )!;
    final c = cat.caixas.indexWhere((c) => c.nome == 'Dex 1-15');
    final l = analisarCaixa(celulas, modelos, caixaForcada: c);
    expect(l.caixa, c);
    expect(l.paraConferir, greaterThan(10)); // nada bate com Bulbasaur & cia.
  });

  test('imagem que não é print do Switch', () {
    expect(
      lerCelulas(File('assets/inicio/midia_fisica.jpg').readAsBytesSync()),
      isNull,
    );
  });
}
