import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositorio.dart';
import '../domain/importacao_csv.dart';
import '../providers.dart';

/// Escolhe um CSV, mostra o que será importado, importa e mostra o resultado.
/// Qualquer falha aparece na tela, em vez de sumir em silêncio.
Future<void> importarCsv(BuildContext context, WidgetRef ref) async {
  try {
    await _importar(context, ref);
  } catch (erro, pilha) {
    debugPrint('Falha na importação: $erro\n$pilha');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Falha na importação'),
        content: SingleChildScrollView(child: SelectableText('$erro')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

void _avisar(BuildContext context, String mensagem) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(mensagem)));
}

Future<void> _importar(BuildContext context, WidgetRef ref) async {
  // file_picker 13: pickFile() devolve o arquivo ou null se cancelar.
  // Sem filtro de tipo: alguns Androids não reconhecem .csv.
  final arquivo = await FilePicker.pickFile();
  if (arquivo == null) {
    if (context.mounted) _avisar(context, 'Nenhum arquivo escolhido.');
    return;
  }
  final List<int>? bytes = await arquivo.readAsBytes();
  if (!context.mounted) return;
  if (bytes == null || bytes.isEmpty) {
    _avisar(context, 'Não foi possível ler "${arquivo.name}".');
    return;
  }

  final leitura = lerCsvImportacao(utf8.decode(bytes, allowMalformed: true));

  final confirma = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Importar CSV'),
      content: SingleChildScrollView(
        child: Text(
          '${leitura.linhas.length} itens prontos para importar.'
          '${leitura.erros.isEmpty ? '' : '\n\n${leitura.erros.length} linhas com problema serão puladas:\n${leitura.erros.join('\n')}'}'
          '\n\nItens que já estão na coleção não são alterados.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              leitura.linhas.isEmpty ? null : () => Navigator.pop(ctx, true),
          child: const Text('Importar'),
        ),
      ],
    ),
  );
  if (confirma != true || !context.mounted) return;

  // Aviso de progresso enquanto importa.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Importando…')),
        ],
      ),
    ),
  );
  final ResultadoImportacao resultado;
  try {
    resultado = await ref.read(repositorioProvider).importar(leitura.linhas);
  } finally {
    // Fecha o aviso de progresso mesmo se der erro.
    if (context.mounted) Navigator.of(context).pop();
  }
  if (!context.mounted) return;

  final partes = [
    '${resultado.importados} itens importados.',
    if (resultado.duplicados.isNotEmpty)
      '${resultado.duplicados.length} já estavam na coleção:\n'
          '${resultado.duplicados.join('\n')}',
    if (resultado.erros.isNotEmpty)
      '${resultado.erros.length} com erro:\n${resultado.erros.join('\n')}',
  ];
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Importação concluída'),
      content: SingleChildScrollView(child: Text(partes.join('\n\n'))),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
