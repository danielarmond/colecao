import 'package:colecao/domain/tipos.dart';
import 'package:colecao/ui/colecao_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filtro "Ativos" esconde só os ignorados', () {
    expect(FiltroStatus.ativos.aceita(StatusItem.naColecao), isTrue);
    expect(FiltroStatus.ativos.aceita(StatusItem.aguardando), isTrue);
    expect(FiltroStatus.ativos.aceita(StatusItem.naFila), isTrue);
    expect(FiltroStatus.ativos.aceita(StatusItem.ignorado), isFalse);
  });

  test('filtro de um status aceita só ele', () {
    expect(FiltroStatus.naFila.aceita(StatusItem.naFila), isTrue);
    expect(FiltroStatus.naFila.aceita(StatusItem.naColecao), isFalse);
    expect(FiltroStatus.ignorados.aceita(StatusItem.ignorado), isTrue);
  });
}
