import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/backup.dart';
import '../domain/exportacao_csv.dart';
import '../providers.dart';
import 'dialogos.dart';
import 'importar_csv.dart';

/// Backup completo (JSON), restauração e planilha (CSV).
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _ocupado = false;

  String get _carimbo => DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Algo deu errado'),
            content: SingleChildScrollView(child: SelectableText('$e')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _salvarBackup() async {
    final servico = ServicoBackup(ref.read(bancoProvider));
    final bytes = await servico.gerarArquivo();
    final destino = await FilePicker.saveFile(
      dialogTitle: 'Salvar backup',
      fileName: 'colecao_backup_$_carimbo.json',
      bytes: Uint8List.fromList(bytes),
    );
    _avisar(destino == null ? 'Backup cancelado.' : 'Backup salvo.');
  }

  Future<void> _restaurar() async {
    final arquivo = await FilePicker.pickFile();
    if (arquivo == null) return;
    final List<int>? bytes = await arquivo.readAsBytes();
    if (bytes == null || bytes.isEmpty) {
      _avisar('Não foi possível ler "${arquivo.name}".');
      return;
    }

    final json = _lerJson(bytes);
    final db = ref.read(bancoProvider);
    final erro = validarBackup(json, versaoEsquema: db.schemaVersion);
    if (erro != null) throw FormatException(erro);

    final mapa = json as Map<String, dynamic>;
    final r = resumirBackup(mapa);
    final atuais = ref.read(itensProvider).value?.length ?? 0;
    final quando = r.geradoEm == null
        ? ''
        : ' de ${DateFormat('dd/MM/yyyy HH:mm').format(r.geradoEm!.toLocal())}';
    if (!mounted) return;

    final ok = await confirmar(
      context,
      titulo: 'Restaurar backup?',
      mensagem: 'O backup$quando tem ${r.itens} itens e ${r.colecoes} '
          'coleções.\n\nTudo o que está no app agora ($atuais itens) será '
          'substituído. Se quiser guardar o estado atual, salve um backup '
          'antes.',
      botao: 'Substituir e restaurar',
    );
    if (!ok) return;

    await ServicoBackup(db).restaurar(mapa);
    _avisar('Backup restaurado: ${r.itens} itens, ${r.colecoes} coleções.');
  }

  static Object? _lerJson(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      throw const FormatException('O arquivo não é um JSON válido.');
    }
  }

  Future<void> _exportarCsv() async {
    final itens = ref.read(itensProvider).value ?? const [];
    final colecoes = ref.read(colecoesProvider).value ?? const [];
    final vinculos = ref.read(vinculosProvider).value ?? const {};
    final nomes = {for (final c in colecoes) c.id: c.nome};

    final csv = gerarCsvExportacao([
      for (final i in itens)
        (
          titulo: i.jogo.titulo,
          plataforma: i.plataforma.nome,
          ano: i.ano,
          colecoes: [
            for (final id in vinculos[i.item.id] ?? const <String>{})
              if (nomes[id] != null) nomes[id]!,
          ]..sort(),
          status: i.item.status,
          valorCentavos: i.item.valorCentavos,
          dataChegada: i.item.dataChegada,
          condicao: i.item.condicao,
          observacoes: i.item.observacoes,
          rawgId: i.jogo.rawgId,
        ),
    ]);
    // BOM para o Excel reconhecer acentos; o Sheets e a importação ignoram.
    final bytes = utf8.encode('﻿$csv');
    final destino = await FilePicker.saveFile(
      dialogTitle: 'Exportar planilha',
      fileName: 'colecao_$_carimbo.csv',
      bytes: Uint8List.fromList(bytes),
    );
    _avisar(destino == null
        ? 'Exportação cancelada.'
        : '${itens.length} itens exportados.');
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup e planilha')),
      body: AbsorbPointer(
        absorbing: _ocupado,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_ocupado) const LinearProgressIndicator(),
            Text('Backup completo', style: texto.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Arquivo .json com tudo: itens, coleções, vínculos com a RAWG, '
              'ignorados e excluídos. Guarde no Drive ou mande para você mesmo.',
              style: texto.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _executar(_salvarBackup),
              icon: const Icon(Icons.save_alt),
              label: const Text('Salvar backup'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _executar(_restaurar),
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar backup'),
            ),
            const Divider(height: 40),
            Text('Planilha', style: texto.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Arquivo .csv que abre no Google Sheets ou no Excel, no mesmo '
              'formato da importação. Não leva as capas: para guardar tudo, '
              'use o backup.',
              style: texto.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _executar(_exportarCsv),
              icon: const Icon(Icons.table_view),
              label: const Text('Exportar planilha (.csv)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _executar(() => importarCsv(context, ref)),
              icon: const Icon(Icons.upload_file),
              label: const Text('Importar planilha (.csv)'),
            ),
          ],
        ),
      ),
    );
  }
}
