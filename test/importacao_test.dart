import 'package:colecao/domain/importacao_csv.dart';
import 'package:colecao/domain/tipos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê o colecao_importacao.csv', () {
    const csv = '﻿titulo,plataforma,ano,franquia,status,valor_pago,data_chegada\r\n'
        'The Legend of Zelda: Link’s Awakening,Game Boy,1993,The Legend of Zelda,na_colecao,70.00,2026-06-29\r\n'
        "Ripened Tingle's Balloon Trip of Love,Nintendo DS,2009,The Legend of Zelda,aguardando,130.00,2026-11-04\r\n"
        "Tingle's Balloon Fight DS,Nintendo DS,2007,The Legend of Zelda,na_fila,,\r\n"
        'Zelda’s Adventure,CD-i,1994,The Legend of Zelda,ignorado,,\r\n';

    final r = lerCsvImportacao(csv);

    expect(r.erros, isEmpty);
    expect(r.linhas, hasLength(4));
    final la = r.linhas.first;
    expect(la.titulo, 'The Legend of Zelda: Link’s Awakening');
    expect(la.plataforma, 'Game Boy');
    expect(la.ano, 1993);
    expect(la.colecoes, ['The Legend of Zelda']);
    expect(la.status, StatusItem.naColecao);
    expect(la.valorCentavos, 7000);
    expect(la.dataChegada, DateTime(2026, 6, 29));
    expect(r.linhas[1].status, StatusItem.aguardando);
    expect(r.linhas[2].valorCentavos, isNull);
    expect(r.linhas[2].dataChegada, isNull);
    expect(r.linhas[3].status, StatusItem.ignorado);
  });

  test('campos entre aspas e separador ponto e vírgula', () {
    const csv = 'titulo;plataforma;status;valor\n'
        '"Jogo; com ponto e vírgula";SNES;Na Coleção;"1.234,56"\n';
    final r = lerCsvImportacao(csv);
    expect(r.erros, isEmpty);
    expect(r.linhas.single.titulo, 'Jogo; com ponto e vírgula');
    expect(r.linhas.single.valorCentavos, 123456);
  });

  test('aponta linhas inválidas sem parar a importação', () {
    const csv = 'titulo,plataforma,status,data_chegada\n'
        'A,NES,na_colecao,2026-02-31\n'
        'B,NES,talvez,\n'
        ',NES,na_fila,\n'
        'C,NES,Não Aplicável,04/11/2026\n';
    final r = lerCsvImportacao(csv);
    expect(r.linhas.single.titulo, 'C');
    expect(r.linhas.single.status, StatusItem.ignorado);
    expect(r.linhas.single.dataChegada, DateTime(2026, 11, 4));
    expect(r.erros.map((e) => e.numero), [2, 3, 4]);
  });

  test('sem as colunas obrigatórias', () {
    final r = lerCsvImportacao('nome,console\nA,NES\n');
    expect(r.linhas, isEmpty);
    expect(r.erros, hasLength(1));
  });
}
