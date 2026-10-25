import 'package:colecao/domain/regras.dart';
import 'package:colecao/domain/tipos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarTitulo', () {
    test('ignora apóstrofo curvo e reto', () {
      expect(
        normalizarTitulo('The Legend of Zelda: Link’s Awakening'),
        normalizarTitulo("The Legend of Zelda: Link's Awakening"),
      );
    });

    test('remove acentos, pontuação e espaços extras', () {
      expect(
        normalizarTitulo('  Coleção:   Edição   Especial! '),
        'colecao edicao especial',
      );
    });
  });

  group('nomeDeExibicao', () {
    const jogo = 'Pokémon Scarlet and Violet';

    test('nome diferente do jogo vira nome próprio da versão', () {
      expect(nomeDeExibicao('  Pokémon Violet ', jogo), 'Pokémon Violet');
    });

    test('vazio ou igual ao jogo (ignorando acentos) usa o título do jogo', () {
      expect(nomeDeExibicao(null, jogo), isNull);
      expect(nomeDeExibicao('   ', jogo), isNull);
      expect(nomeDeExibicao('pokemon scarlet and violet', jogo), isNull);
    });
  });

  group('lerValorCentavos', () {
    test('formato brasileiro', () {
      expect(lerValorCentavos('117,90'), 11790);
      expect(lerValorCentavos('1.234,56'), 123456);
      expect(lerValorCentavos('R\$ 50'), 5000);
    });

    test('arredonda a terceira casa (valores da planilha)', () {
      expect(lerValorCentavos('117.895'), 11790);
      expect(lerValorCentavos('117,894'), 11789);
    });

    test('vazio vira nulo', () {
      expect(lerValorCentavos(''), isNull);
      expect(lerValorCentavos('  '), isNull);
    });

    test('texto inválido lança erro', () {
      expect(() => lerValorCentavos('abc'), throwsFormatException);
      expect(() => lerValorCentavos('1.2.3'), throwsFormatException);
    });
  });

  group('formatarCentavos', () {
    test('com milhar e centavos', () {
      expect(formatarCentavos(1168630), 'R\$ 11.686,30');
      expect(formatarCentavos(7000), 'R\$ 70,00');
      expect(formatarCentavos(5), 'R\$ 0,05');
    });

    test('ida e volta pelo campo de edição', () {
      expect(lerValorCentavos(centavosParaCampo(123456)), 123456);
    });
  });

  group('ResumoColecao', () {
    // A planilha de Zelda: 43 na coleção, 2 aguardando, 3 na fila, 3 ignorados.
    final itens = [
      for (var i = 0; i < 43; i++)
        (status: StatusItem.naColecao, valorCentavos: 100),
      (status: StatusItem.aguardando, valorCentavos: 13000),
      (status: StatusItem.aguardando, valorCentavos: 13000),
      for (var i = 0; i < 3; i++)
        (status: StatusItem.naFila, valorCentavos: null),
      for (var i = 0; i < 3; i++)
        (status: StatusItem.ignorado, valorCentavos: 999),
    ];

    test('progresso exclui ignorados: 45 de 48 = 94%', () {
      final r = ResumoColecao.calcular(itens);
      expect(r.meus, 45);
      expect(r.meta, 48);
      expect((r.progresso! * 100).round(), 94);
    });

    test('gasto soma só Na Coleção e Aguardando', () {
      final r = ResumoColecao.calcular(itens);
      expect(r.gastoCentavos, 43 * 100 + 2 * 13000);
    });

    test('sem meta, progresso é nulo', () {
      expect(ResumoColecao.calcular(const []).progresso, isNull);
    });
  });
}
