import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/banco.dart';
import '../../livingdex/catalogo.dart';
import '../../livingdex/leitor_caixa.dart';
import '../../providers.dart';
import 'miniatura.dart';
import 'revisao_espaco.dart';

/// Decodifica e recorta o print noutro isolate. Função de topo para que a
/// closure leve só os bytes (nada da tela).
Future<List<Uint8List?>?> _lerEmSegundoPlano(Uint8List bytes) =>
    Isolate.run(() => lerCelulas(bytes));

Future<Uint8List?> _recortarEmSegundoPlano(Uint8List bytes, int espaco) =>
    Isolate.run(() => recortarEspaco(bytes, espaco));

/// Carga por print: você escolhe prints das caixas do HOME na galeria, o app
/// reconhece cada caixa e mostra o que leu para você conferir antes de salvar.
class CargaPrintsPage extends ConsumerStatefulWidget {
  const CargaPrintsPage({super.key});

  @override
  ConsumerState<CargaPrintsPage> createState() => _CargaPrintsPageState();
}

class _Print {
  _Print({required this.nome, required this.bytes, required this.celulas});

  final String nome;
  final Uint8List bytes;

  /// null = não é um print do Switch (proporção diferente).
  final List<Uint8List?>? celulas;
  LeituraCaixa? leitura;
  bool ignorar = false;

  /// Recortes ampliados já gerados, por espaço.
  final _recortes = <int, Future<Uint8List?>>{};
  Future<Uint8List?> recorte(int espaco) =>
      _recortes[espaco] ??= _recortarEmSegundoPlano(bytes, espaco);
}

class _CargaPrintsPageState extends ConsumerState<CargaPrintsPage> {
  final _prints = <_Print>[];
  String? _andamento;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _escolher());
  }

  Future<void> _escolher() async {
    final arquivos = await ImagePicker().pickMultiImage();
    if (arquivos.isEmpty || !mounted) return;
    final modelos = await ref.read(modelosDexProvider.future);
    for (final (i, a) in arquivos.indexed) {
      if (!mounted) return;
      setState(() => _andamento = 'Lendo ${i + 1} de ${arquivos.length}…');
      final bytes = await a.readAsBytes();
      // Decodificar e recortar é o trabalho pesado: fora da tela.
      final celulas = await _lerEmSegundoPlano(bytes);
      final p = _Print(nome: a.name, bytes: bytes, celulas: celulas);
      if (celulas != null) p.leitura = analisarCaixa(celulas, modelos);
      p.ignorar = p.leitura == null ||
          p.leitura!.tipo == TipoLeitura.desconhecida;
      _prints.add(p);
    }
    if (mounted) setState(() => _andamento = null);
  }

  Map<String, bool> _mudancas() {
    final m = <String, bool>{};
    for (final p in _prints) {
      final l = p.leitura;
      if (p.ignorar || l == null) continue;
      mudancasDaLeitura(l, m);
    }
    return m;
  }

  Future<void> _salvar() async {
    final tenho = ref.read(dexTenhoProvider).value ?? const <String>{};
    final mudancas = _mudancas();
    final novos = mudancas.entries
        .where((e) => e.value && !tenho.contains(e.key))
        .length;
    final removidos = mudancas.entries
        .where((e) => !e.value && tenho.contains(e.key))
        .length;
    final pendentes = [
      for (final p in _prints)
        if (!p.ignorar && p.leitura != null)
          for (final (k, e) in p.leitura!.espacos.indexed)
            if (e.pendente) (p, k, e),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar a carga?'),
        content: Text(
          '$novos Pokémon entram como "tenho" e $removidos saem '
          '(espaços vazios nas caixas lidas).'
          '${pendentes.isEmpty ? '' : '\n\n${pendentes.length} espaços vão '
              'para Aguardando validação, sem mudar nada na LivingDex.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final catalogo = ref.read(catalogoDexProvider).value;
    final registros = <DexPendenciasCompanion>[];
    for (final (p, k, e) in pendentes) {
      final recorte = await p.recorte(k);
      if (recorte == null) continue;
      final l = p.leitura!;
      final caixa = l.tipo == TipoLeitura.caixaDex && catalogo != null
          ? catalogo.caixas[l.caixa!].nome
          : 'Caixa de formas';
      registros.add(
        DexPendenciasCompanion.insert(
          recorte: recorte,
          shiny: e.shiny,
          sugestaoId: Value(e.atual?.id),
          origem: '$caixa · linha ${k ~/ 6 + 1}, coluna ${k % 6 + 1}',
        ),
      );
    }
    await ref
        .read(repositorioDexProvider)
        .aplicar(mudancas, pendencias: registros);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Carga salva: +$novos, −$removidos'
          '${registros.isEmpty ? '' : ', ${registros.length} para validar'}.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoDexProvider).value;
    final modelos = ref.watch(modelosDexProvider).value;
    final usaveis = _prints.where((p) => !p.ignorar && p.leitura != null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carregar prints'),
        actions: [
          IconButton(
            tooltip: 'Escolher mais prints',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _andamento == null ? _escolher : null,
          ),
        ],
      ),
      body: _andamento != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_andamento!),
                ],
              ),
            )
          : _prints.isEmpty || catalogo == null || modelos == null
              ? const _Instrucoes()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  children: [
                    for (final p in _prints)
                      _CartaoPrint(
                        entrada: p,
                        catalogo: catalogo,
                        onCaixa: (c) => setState(() {
                          final cel = p.celulas;
                          if (cel == null) return;
                          if (c == null) {
                            p.ignorar = true;
                          } else {
                            p.leitura =
                                analisarCaixa(cel, modelos, caixaForcada: c);
                            p.ignorar = false;
                          }
                        }),
                        onAlterou: () => setState(() {}),
                      ),
                  ],
                ),
      floatingActionButton: usaveis.isEmpty || _andamento != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _salvar,
              icon: const Icon(Icons.save_outlined),
              label: Text('Salvar ${usaveis.length} caixas'),
            ),
    );
  }
}

class _Instrucoes extends StatelessWidget {
  const _Instrucoes();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Escolha na galeria os prints das caixas do Pokémon HOME, tirados '
          'no Switch (botão de captura). Cada caixa "Dex X-Y" é reconhecida '
          'pelo conteúdo; os espaços duvidosos ficam marcados para você '
          'conferir.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CartaoPrint extends StatelessWidget {
  const _CartaoPrint({
    required this.entrada,
    required this.catalogo,
    required this.onCaixa,
    required this.onAlterou,
  });

  final _Print entrada;
  final CatalogoDex catalogo;

  /// Índice da caixa escolhida, ou null para ignorar o print.
  final ValueChanged<int?> onCaixa;
  final VoidCallback onAlterou;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final l = entrada.leitura;

    final String titulo;
    final String detalhe;
    if (l == null) {
      titulo = 'Não é um print do Switch';
      detalhe = entrada.nome;
    } else if (entrada.ignorar) {
      titulo = 'Ignorado';
      detalhe = l.tipo == TipoLeitura.desconhecida
          ? 'Caixa não reconhecida (ex.: a temporária)'
          : entrada.nome;
    } else {
      titulo = switch (l.tipo) {
        TipoLeitura.caixaDex => catalogo.caixas[l.caixa!].nome,
        TipoLeitura.regionais => 'Caixa de formas',
        TipoLeitura.desconhecida => 'Não reconhecida',
      };
      detalhe = '${l.ocupados} ocupados'
          '${l.paraConferir > 0 ? ' · ${l.paraConferir} para conferir' : ''}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => _verPrint(context, entrada),
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          entrada.bytes,
                          width: 112,
                          height: 63,
                          fit: BoxFit.cover,
                          cacheWidth: 320,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.zoom_in,
                          size: 18,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: texto.titleMedium),
                      Text(
                        detalhe,
                        style: texto.bodySmall?.copyWith(
                          color: l != null && l.paraConferir > 0 && !entrada.ignorar
                              ? Colors.orange.shade800
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entrada.celulas != null)
                  PopupMenuButton<int>(
                    tooltip: 'Escolher a caixa',
                    icon: const Icon(Icons.edit_outlined),
                    onSelected: (c) => onCaixa(c < 0 ? null : c),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: -1, child: Text('Ignorar')),
                      for (final (i, c) in catalogo.caixas.indexed)
                        if (c.pokemon.every((p) => !p.formaExtra))
                          PopupMenuItem(value: i, child: Text(c.nome)),
                    ],
                  ),
              ],
            ),
            if (l != null && !entrada.ignorar) ...[
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 30,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, k) {
                  final e = l.espacos[k];
                  final p = e.atual;
                  return Tooltip(
                    message: p == null
                        ? 'Sem Pokémon neste espaço'
                        : '${p.nome}${e.shiny ? ' (shiny)' : ''}'
                            '${e.ocupado ? '' : ' · vazio'}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      // Toque abre a revisão do espaço.
                      onTap: () async {
                        await _revisarEspaco(context, entrada, k, catalogo);
                        onAlterou();
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.shiny
                              ? cores.tertiaryContainer.withValues(alpha: 0.35)
                              : cores.surfaceContainerHighest,
                          border: e.confira
                              ? Border.all(
                                  color: Colors.orange.shade700,
                                  width: 2.5,
                                )
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: !e.ocupado && e.temImagem
                              ? Icon(
                                  Icons.pending_actions,
                                  size: 18,
                                  color: Colors.orange.shade700,
                                )
                              : p == null || !e.ocupado
                              ? null
                              : MiniaturaDex(
                                  pokemon: p,
                                  shiny: e.shiny,
                                  tenho: true,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Print inteiro, com zoom, e os espaços para conferir destacados.
void _verPrint(BuildContext context, _Print entrada, {int? destaque}) {
  final l = entrada.leitura;
  final marcados = <int>{
    if (l != null && !entrada.ignorar)
      for (final (k, e) in l.espacos.indexed)
        if (e.confira) k,
    if (destaque != null) destaque,
  };
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(entrada.nome, overflow: TextOverflow.ellipsis),
        ),
        body: InteractiveViewer(
          maxScale: 8,
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(entrada.bytes, fit: BoxFit.contain),
                  CustomPaint(painter: _Destaques(marcados)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Destaques extends CustomPainter {
  _Destaques(this.espacos);

  final Set<int> espacos;

  @override
  void paint(Canvas canvas, Size s) {
    final tinta = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final k in espacos) {
      final r = retanguloEspaco(k);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.x * s.width, r.y * s.height, r.w * s.width,
              r.h * s.height),
          const Radius.circular(6),
        ),
        tinta,
      );
    }
  }

  @override
  bool shouldRepaint(_Destaques old) => old.espacos != espacos;
}

/// Revisão de um espaço do print: recorte ampliado, o que o app entendeu e
/// as opções de corrigir.
Future<void> _revisarEspaco(
  BuildContext context,
  _Print entrada,
  int k,
  CatalogoDex catalogo,
) async {
  final e = entrada.leitura!.espacos[k];
  final acao = await mostrarRevisao(
    context,
    titulo: 'Linha ${k ~/ 6 + 1}, coluna ${k % 6 + 1} · '
        '${e.shiny ? 'Shiny' : 'Regular'}',
    recorte: entrada.recorte(k),
    atual: e.atual,
    shiny: e.shiny,
    opcoes: [
      if (e.atual != null)
        OpcaoRevisao('certo', 'Está certo: ${e.atual!.nome}', Icons.check,
            principal: true),
      const OpcaoRevisao('escolher', 'Escolher outro Pokémon', Icons.search),
      e.temImagem
          ? const OpcaoRevisao(
              'vazio',
              'Remover (vai para Aguardando validação)',
              Icons.pending_actions,
            )
          : const OpcaoRevisao(
              'vazio',
              'Espaço vazio',
              Icons.remove_circle_outline,
            ),
      const OpcaoRevisao('print', 'Ver o print inteiro', Icons.zoom_in,
          discreta: true),
    ],
  );

  if (!context.mounted) return;
  switch (acao) {
    case 'certo':
      e.ocupado = true;
      e.confirmado = true;
    case 'vazio':
      e.ocupado = false;
      e.confirmado = true;
      e.escolhido = null;
    case 'escolher':
      final p = await escolherPokemon(
        context,
        catalogo,
        shiny: e.shiny,
        formasPrimeiro: entrada.leitura!.tipo == TipoLeitura.regionais,
      );
      if (p != null) {
        e.escolhido = p.id == e.pokemon?.id ? null : p;
        e.ocupado = true;
        e.confirmado = true;
      }
    case 'print':
      _verPrint(context, entrada, destaque: k);
  }
}
