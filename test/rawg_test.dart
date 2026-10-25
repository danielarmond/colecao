import 'package:colecao/data/rawg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê um resultado da busca da RAWG', () {
    final j = RawgJogo.fromJson({
      'id': 27015,
      'name': 'The Legend of Zelda: Twilight Princess',
      'released': '2006-11-19',
      'background_image':
          'https://media.rawg.io/media/games/abc/abc123.jpg',
      'rating': 4.38,
      'ratings_count': 501,
      'platforms': [
        {
          'platform': {'id': 105, 'name': 'GameCube'},
          'released_at': '2006-12-02',
        },
        {
          'platform': {'id': 11, 'name': 'Wii'},
          'released_at': null,
        },
      ],
    });

    expect(j.id, 27015);
    expect(j.ano, 2006);
    expect(j.capaUrl,
        'https://media.rawg.io/media/crop/600/400/games/abc/abc123.jpg');
    expect(j.plataformas.map((p) => p.id), [105, 11]);
    expect(j.anoEm(105), 2006);
    expect(j.anoEm(11), 2006); // sem data na plataforma: usa a do jogo
    expect(j.anoEm(null), 2006);
    expect(j.nota, 4.38);
    expect(j.votos, 501);
  });

  test('campos ausentes não quebram', () {
    final j = RawgJogo.fromJson({'id': 1, 'name': 'X'});
    expect(j.ano, isNull);
    expect(j.capaUrl, isNull);
    expect(j.plataformas, isEmpty);
  });

  test('sem chave, a busca avisa em vez de chamar a API', () {
    final cliente = RawgCliente(chave: '');
    expect(cliente.configurado, isFalse);
    expect(() => cliente.buscar('zelda'), throwsA(isA<RawgErro>()));
  });
}
