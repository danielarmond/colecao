import 'package:colecao/data/lote.dart';
import 'package:colecao/data/rawg.dart';
import 'package:colecao/domain/tipos.dart';
import 'package:flutter_test/flutter_test.dart';

RawgJogo jogo(int id, String nome, int ano, Map<int, int?> plataformas) =>
    RawgJogo(
      id: id,
      nome: nome,
      ano: ano,
      plataformas: [
        for (final e in plataformas.entries)
          RawgPlataforma(id: e.key, nome: 'p${e.key}', ano: e.value),
      ],
    );

void main() {
  // Plataformas do app com rawgId: GameCube (105), Wii (11), Switch (7).
  const gc = (id: 'gc', rawgId: 105, nome: 'GameCube');
  const wii = (id: 'wii', rawgId: 11, nome: 'Wii');
  const nsw = (id: 'nsw', rawgId: 7, nome: 'Nintendo Switch');

  final tp = jogo(27015, 'The Legend of Zelda: Twilight Princess', 2006,
      {105: 2006, 11: 2006, 10: 2016});
  final ww = jogo(1, 'The Legend of Zelda: The Wind Waker', 2002, {105: 2002});
  final eow = jogo(2, 'The Legend of Zelda: Echoes of Wisdom', 2024, {7: 2024});
  final mm = jogo(3, "Majora's Mask", 2000, {7: 2022});

  test('cruza jogos com as plataformas escolhidas, sem repetir', () {
    final c = montarCandidatos(
      jogos: [tp, ww, tp], // repetido de propósito
      plataformas: [gc, wii],
      existentes: const [],
    );
    expect(c.map((x) => x.chave), [
      '1|gc', // 2002
      '27015|gc', // 2006, GameCube antes de Wii
      '27015|wii',
    ]);
    expect(c.every((x) => x.novo), isTrue);
  });

  test('reconhece o que você já tem, por id da RAWG ou por título', () {
    final c = montarCandidatos(
      jogos: [tp, ww],
      plataformas: [gc, wii],
      existentes: const [
        (
          itemId: 'i1',
          rawgId: 27015,
          tituloBusca: 'x',
          plataformaId: 'gc',
          status: StatusItem.naColecao,
        ),
        (
          itemId: 'i2',
          rawgId: null,
          tituloBusca: 'the legend of zelda the wind waker',
          plataformaId: 'gc',
          status: StatusItem.naFila,
        ),
      ],
    );
    final porChave = {for (final x in c) x.chave: x};
    expect(porChave['27015|gc']!.existente!.itemId, 'i1');
    expect(porChave['1|gc']!.existente!.itemId, 'i2');
    expect(porChave['27015|wii']!.novo, isTrue);
  });

  test('ignorados não voltam', () {
    final c = montarCandidatos(
      jogos: [tp],
      plataformas: [gc, wii],
      existentes: const [
        (
          itemId: 'i1',
          rawgId: 27015,
          tituloBusca: '',
          plataformaId: 'wii',
          status: StatusItem.ignorado,
        ),
      ],
    );
    expect(c.map((x) => x.chave), ['27015|gc']);
  });

  test('filtra pelo ano na plataforma', () {
    final c = montarCandidatos(
      jogos: [tp, ww, eow, mm],
      plataformas: [gc, nsw],
      existentes: const [],
      anoDe: 2005,
      anoAte: 2023,
    );
    // Majora's Mask: ano no Switch é 2022 (relançamento), entra.
    expect(c.map((x) => x.chave), ['27015|gc', '3|nsw']);
  });
}
