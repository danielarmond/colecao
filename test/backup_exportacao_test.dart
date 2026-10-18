import 'package:colecao/data/backup.dart';
import 'package:colecao/domain/exportacao_csv.dart';
import 'package:colecao/domain/importacao_csv.dart';
import 'package:colecao/domain/tipos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('exportação CSV', () {
    final linhas = <LinhaExportacao>[
      (
        titulo: 'The Legend of Zelda: Link’s Awakening',
        plataforma: 'Game Boy',
        ano: 1993,
        colecoes: ['The Legend of Zelda', 'Game Boy'],
        status: StatusItem.naColecao,
        valorCentavos: 7000,
        dataChegada: DateTime(2026, 6, 29),
        condicao: Condicao.completo,
        observacoes: 'Caixa amassada, "ok"',
        rawgId: 27057,
      ),
      (
        titulo: "Tingle's Balloon Fight DS",
        plataforma: 'Nintendo DS',
        ano: null,
        colecoes: const [],
        status: StatusItem.naFila,
        valorCentavos: null,
        dataChegada: null,
        condicao: null,
        observacoes: null,
        rawgId: null,
      ),
    ];

    test('ida e volta: exportar e importar dá os mesmos dados', () {
      final csv = gerarCsvExportacao(linhas);
      final lido = lerCsvImportacao(csv);

      expect(lido.erros, isEmpty);
      expect(lido.linhas, hasLength(2));
      final a = lido.linhas.first;
      expect(a.titulo, 'The Legend of Zelda: Link’s Awakening');
      expect(a.plataforma, 'Game Boy');
      expect(a.ano, 1993);
      expect(a.colecoes, ['The Legend of Zelda', 'Game Boy']);
      expect(a.status, StatusItem.naColecao);
      expect(a.valorCentavos, 7000);
      expect(a.dataChegada, DateTime(2026, 6, 29));
      expect(a.condicao, Condicao.completo);
      expect(a.observacoes, 'Caixa amassada, "ok"');
      expect(a.rawgId, 27057);

      final b = lido.linhas.last;
      expect(b.status, StatusItem.naFila);
      expect(b.colecoes, isEmpty);
      expect(b.valorCentavos, isNull);
      expect(b.rawgId, isNull);
    });

    test('valores com ponto decimal e campos com vírgula entre aspas', () {
      final csv = gerarCsvExportacao(linhas);
      expect(csv, contains(',70.00,'));
      expect(csv, contains('"Caixa amassada, ""ok"""'));
    });
  });

  group('validarBackup', () {
    Map<String, dynamic> backup({int versao = 2}) => {
          'formato': formatoBackup,
          'versaoEsquema': versao,
          'geradoEm': '2026-10-18T03:00:00.000Z',
          for (final t in tabelasBackup) t: <Map<String, dynamic>>[],
        };

    test('aceita backup da mesma versão', () {
      expect(validarBackup(backup(), versaoEsquema: 2), isNull);
    });

    test('recusa arquivo que não é backup', () {
      expect(validarBackup({'a': 1}, versaoEsquema: 2), isNotNull);
      expect(validarBackup([1, 2], versaoEsquema: 2), isNotNull);
    });

    test('recusa versão diferente', () {
      expect(validarBackup(backup(versao: 3), versaoEsquema: 2),
          contains('mais nova'));
      expect(validarBackup(backup(versao: 1), versaoEsquema: 2),
          contains('antiga'));
    });

    test('recusa backup incompleto', () {
      final b = backup()..remove('colecoes');
      expect(validarBackup(b, versaoEsquema: 2), contains('colecoes'));
    });

    test('resumo conta só o que não foi excluído', () {
      final b = backup()
        ..['itensColecao'] = [
          {'id': 'a', 'excluidoEm': null},
          {'id': 'b', 'excluidoEm': 123},
        ]
        ..['colecoes'] = [
          {'id': 'z', 'excluidoEm': null},
        ];
      final r = resumirBackup(b);
      expect(r.itens, 1);
      expect(r.colecoes, 1);
      expect(r.geradoEm, DateTime.utc(2026, 10, 18, 3));
    });
  });
}
