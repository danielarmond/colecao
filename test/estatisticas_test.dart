import 'package:colecao/domain/estatisticas.dart';
import 'package:colecao/domain/tipos.dart';
import 'package:flutter_test/flutter_test.dart';

ItemEstatistica item(
  String titulo,
  String plataforma,
  StatusItem status, {
  int? pago,
  int? mercado,
}) =>
    (
      titulo: titulo,
      plataforma: plataforma,
      status: status,
      valorCentavos: pago,
      valorMercadoCentavos: mercado,
    );

void main() {
  final itens = [
    item('TP', 'GameCube', StatusItem.naColecao, pago: 81100, mercado: 90000),
    item('WW', 'GameCube', StatusItem.naColecao, pago: 23000),
    item('LA', 'Game Boy', StatusItem.naColecao, pago: 7000, mercado: 15000),
    item('Tingle', 'Nintendo DS', StatusItem.aguardando, pago: 13000),
    item('Sem valor', 'Nintendo DS', StatusItem.naColecao),
    // Fora da conta: não são seus.
    item('Fila', 'NES', StatusItem.naFila, pago: 99999, mercado: 99999),
    item('Ignorado', 'CD-i', StatusItem.ignorado, pago: 99999),
  ];

  test('valor pago conta só Na Coleção e Aguardando', () {
    final e = Estatisticas.calcular(itens);
    expect(e.itens, 5);
    expect(e.pagoCentavos, 81100 + 23000 + 7000 + 13000);
    expect(e.itensComValor, 4);
    expect(e.mediaCentavos, ((81100 + 23000 + 7000 + 13000) / 4).round());
    expect(e.maisCaro, (titulo: 'TP', valorCentavos: 81100));
  });

  test('mercado compara só itens que têm valor de mercado', () {
    final e = Estatisticas.calcular(itens);
    expect(e.itensComMercado, 2);
    expect(e.mercadoCentavos, 90000 + 15000);
    expect(e.pagoDosComMercado, 81100 + 7000);
    expect(e.valorizacaoCentavos, (90000 + 15000) - (81100 + 7000));
  });

  test('por plataforma, da que mais custou para a que menos custou', () {
    final e = Estatisticas.calcular(itens);
    expect(e.porPlataforma.map((p) => p.plataforma),
        ['GameCube', 'Nintendo DS', 'Game Boy']);
    final gc = e.porPlataforma.first;
    expect(gc.itens, 2);
    expect(gc.pagoCentavos, 104100);
    expect(gc.mercadoCentavos, 90000);
  });

  test('sem itens, nada quebra', () {
    final e = Estatisticas.calcular(const []);
    expect(e.itens, 0);
    expect(e.mediaCentavos, isNull);
    expect(e.valorizacaoCentavos, isNull);
    expect(e.maisCaro, isNull);
    expect(e.porPlataforma, isEmpty);
  });
}
