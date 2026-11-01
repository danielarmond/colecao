import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../livingdex/catalogo.dart';
import '../../providers.dart';
import 'livingdex_page.dart';

/// Estatísticas da LivingDex: progresso por geração e, do que falta, quanto
/// aparece na Pokédex de cada jogo do Switch. Tocar numa barra abre a lista
/// filtrada.
class EstatisticasDexPage extends ConsumerStatefulWidget {
  const EstatisticasDexPage({super.key});

  @override
  ConsumerState<EstatisticasDexPage> createState() =>
      _EstatisticasDexPageState();
}

class _EstatisticasDexPageState extends ConsumerState<EstatisticasDexPage> {
  bool _shiny = false;
  bool _semLendarios = false;

  @override
  Widget build(BuildContext context) {
    final cat = ref.watch(catalogoDexProvider).value;
    final tenho = ref.watch(dexTenhoProvider).value ?? const <String>{};
    final ajustes = ref.watch(dexAjustesProvider).value ?? const <int, bool>{};
    final texto = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;

    if (cat == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final porGeracao = progressoPorGeracao(
      cat,
      shiny: _shiny,
      tenho: tenho,
      ajustes: ajustes,
      semLendarios: _semLendarios,
    );
    final jogos = faltamPorJogo(
      cat,
      shiny: _shiny,
      tenho: tenho,
      ajustes: ajustes,
      semLendarios: _semLendarios,
    );
    final ordemJogos = JogoDex.values.toList()
      ..sort((a, b) => jogos.porJogo[b]!.compareTo(jogos.porJogo[a]!));
    final maiorJogo = jogos.porJogo.values.fold<int>(0, (a, b) => a > b ? a : b);

    void abrirLista(FiltroDex filtro) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LivingDexPage(filtroInicial: filtro),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas · LivingDex')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Regular')),
                ButtonSegment(value: true, label: Text('Shiny')),
              ],
              selected: {_shiny},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _shiny = s.first),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sem lendários e míticos'),
            subtitle: const Text('Tira os dois grupos de todas as contas.'),
            value: _semLendarios,
            onChanged: (v) => setState(() => _semLendarios = v),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Por geração', style: texto.titleMedium),
                  Text(
                    'Quanto você já tem de cada geração. Toque para ver o '
                    'que falta.',
                    style: texto.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final (g, nome, _) in geracoes)
                    _LinhaBarra(
                      rotulo: 'Gen $g',
                      detalhe: nome,
                      fracao: porGeracao[g]!.total == 0
                          ? 0
                          : porGeracao[g]!.tenho / porGeracao[g]!.total,
                      valor: '${porGeracao[g]!.tenho}/${porGeracao[g]!.total}'
                          ' · ${_pct(porGeracao[g]!.tenho, porGeracao[g]!.total)}',
                      cor: cores.primary,
                      onTap: () => abrirLista(
                        FiltroDex(
                          shiny: _shiny,
                          posse: PosseDex.falta,
                          geracao: g,
                          semLendarios: _semLendarios,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Onde encontrar o que falta', style: texto.titleMedium),
                  Text(
                    'Dos ${jogos.faltam} que faltam, quantos aparecem na '
                    'Pokédex de cada jogo do Switch. Um Pokémon pode estar em '
                    'mais de um jogo.',
                    style: texto.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final j in ordemJogos)
                    _LinhaBarra(
                      rotulo: j.rotulo,
                      fracao: maiorJogo == 0
                          ? 0
                          : jogos.porJogo[j]! / maiorJogo,
                      valor: '${jogos.porJogo[j]}'
                          ' · ${_pct(jogos.porJogo[j]!, jogos.faltam)}',
                      cor: cores.tertiary,
                      onTap: () => abrirLista(
                        FiltroDex(
                          shiny: _shiny,
                          posse: PosseDex.falta,
                          jogo: j,
                          semLendarios: _semLendarios,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Em nenhuma Pokédex do Switch: ${jogos.emNenhum} '
                    '(eventos, jogos antigos ou o GO).',
                    style: texto.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _pct(int a, int total) =>
      total == 0 ? '0%' : '${(a * 100 / total).round()}%';
}

class _LinhaBarra extends StatelessWidget {
  const _LinhaBarra({
    required this.rotulo,
    required this.fracao,
    required this.valor,
    required this.cor,
    required this.onTap,
    this.detalhe,
  });

  final String rotulo;
  final String? detalhe;
  final double fracao;
  final String valor;
  final Color cor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final fundo = Theme.of(context).colorScheme.surfaceContainerHighest;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(rotulo, style: texto.labelLarge),
                if (detalhe != null) ...[
                  const SizedBox(width: 6),
                  Text(detalhe!, style: texto.bodySmall),
                ],
                const Spacer(),
                Text(valor, style: texto.labelMedium),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 10, color: fundo),
                  FractionallySizedBox(
                    widthFactor: fracao.clamp(0.0, 1.0).toDouble(),
                    child: Container(height: 10, color: cor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
