import 'package:colecao/domain/importacao_csv.dart';
import 'package:colecao/domain/notas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tier e número', () {
    test('cada nota vira o tier combinado', () {
      expect(
        [for (var n = 10; n >= 0; n--) tierDaNota(n)],
        ['SS', 'S', 'A', 'B', 'C', 'D', 'E', 'E', 'E', 'E', 'E'],
      );
    });

    test('cada tier grava a nota combinada', () {
      expect(notaDoTier('SS'), 10);
      expect(notaDoTier('a'), 8);
      expect(notaDoTier(' E '), 4);
      expect(notaDoTier('F'), isNull);
    });

    test('ida e volta: tier -> nota -> tier', () {
      for (final (tier, _) in tiers) {
        expect(tierDaNota(notaDoTier(tier)!), tier);
      }
    });
  });

  test('formata conforme a escala', () {
    expect(formatarNota(8, EscalaNota.numero), '8');
    expect(formatarNota(8, EscalaNota.tier), 'A');
    expect(formatarNota(null, EscalaNota.tier), isNull);
  });

  test('nota da comunidade', () {
    expect(formatarNotaComunidade(4.38, 501), '★ 4,4 (501)');
    expect(formatarNotaComunidade(4.0, null), '★ 4,0');
    expect(formatarNotaComunidade(0, 0), isNull); // ninguém votou
    expect(formatarNotaComunidade(null, null), isNull);
  });

  test('escala salva como texto', () {
    expect(EscalaNota.deTexto('tier'), EscalaNota.tier);
    expect(EscalaNota.deTexto(null), EscalaNota.numero);
    expect(EscalaNota.deTexto('outra'), EscalaNota.numero);
  });

  test('CSV aceita nota em número ou tier e zerado', () {
    const csv = 'titulo,plataforma,status,nota,zerado\n'
        'A,NES,na_colecao,9,sim\n'
        'B,NES,na_colecao,S,\n'
        'C,NES,na_colecao,11,x\n';
    final r = lerCsvImportacao(csv);
    expect(r.erros, isEmpty);
    expect(r.linhas.map((l) => l.nota), [9, 9, null]);
    expect(r.linhas.map((l) => l.zerado), [true, false, true]);
  });
}
