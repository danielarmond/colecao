import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/banco.dart';
import '../domain/estatisticas.dart';
import '../domain/notas.dart';
import '../domain/regras.dart';
import '../providers.dart';
import 'status_visual.dart';

/// Estatísticas da aba aberta: todas as coleções (colecao == null) ou uma.
/// O valor de mercado está pausado (sem fonte de preços); o cálculo continua
/// em [Estatisticas] para quando o recurso voltar.
class EstatisticasPage extends ConsumerWidget {
  const EstatisticasPage({super.key, this.colecao});

  final Colecao? colecao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens = ref.watch(itensProvider).value ?? const [];
    final vinculos = ref.watch(vinculosProvider).value ?? const {};
    final c = colecao;

    final daAba = c == null
        ? itens
        : itens.where((i) => vinculos[i.item.id]?.contains(c.id) ?? false);
    final e = Estatisticas.calcular([
      for (final i in daAba)
        (
          titulo: i.titulo,
          plataforma: i.plataforma.nome,
          status: i.item.status,
          valorCentavos: i.item.valorCentavos,
          valorMercadoCentavos: null,
        ),
    ]);

    final texto = Theme.of(context).textTheme;
    String reais(int? v) => v == null ? '—' : formatarCentavos(v);
    final maisCaro = e.maisCaro;

    // Zerados e nota da comunidade, entre os itens que são seus.
    final meus = daAba.where((i) => i.item.status.ehMeu).toList();
    final zerados = meus.where((i) => i.item.zerado).length;
    final comunidade = [
      for (final i in meus)
        if ((i.jogo.notaComunidade ?? 0) > 0) i.jogo.notaComunidade!,
    ];
    final mediaComunidade = comunidade.isEmpty
        ? null
        : comunidade.reduce((a, b) => a + b) / comunidade.length;

    return Scaffold(
      appBar: AppBar(title: Text('Estatísticas · ${c?.nome ?? 'Todos'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Contam só os itens Na Coleção e Aguardando (${e.itens}).',
            style: texto.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valor pago', style: texto.labelLarge),
                  const SizedBox(height: 4),
                  Text(reais(e.pagoCentavos), style: texto.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${e.itensComValor} de ${e.itens} itens com valor '
                    'informado',
                  ),
                  Text('Média por item: ${reais(e.mediaCentavos)}'),
                  if (maisCaro != null)
                    Text(
                      'Mais caro: ${maisCaro.titulo} '
                      '(${reais(maisCaro.valorCentavos)})',
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
                  Row(
                    children: [
                      Text('Zerados', style: texto.labelLarge),
                      const SizedBox(width: 4),
                      const MedalhaZerado(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$zerados de ${e.itens}',
                    style: texto.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nota média da comunidade: '
                    '${mediaComunidade == null ? '—' : formatarNotaComunidade(mediaComunidade, null)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Por plataforma', style: texto.titleMedium),
          const SizedBox(height: 4),
          if (e.porPlataforma.isEmpty)
            const Text('Nenhum item seu nesta aba.')
          else
            for (final p in e.porPlataforma)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.plataforma),
                subtitle: Text('${p.itens} ${p.itens == 1 ? 'item' : 'itens'}'),
                trailing: Text(reais(p.pagoCentavos), style: texto.titleSmall),
              ),
        ],
      ),
    );
  }
}
