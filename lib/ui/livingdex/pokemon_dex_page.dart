import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../livingdex/catalogo.dart';
import '../../providers.dart';
import 'miniatura.dart';

/// Tela de um Pokémon: o que você tem, onde fica na caixa e os dados gerais.
class PokemonDexPage extends ConsumerWidget {
  const PokemonDexPage({super.key, required this.pokemon});

  final PokemonDex pokemon;

  static const _nomesStatus = [
    'HP',
    'Attack',
    'Defense',
    'Sp. Atk',
    'Sp. Def',
    'Speed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pokemon;
    final tenho = ref.watch(dexTenhoProvider).value ?? const <String>{};
    final ajustes = ref.watch(dexAjustesProvider).value ?? const <int, bool>{};
    final catalogo = ref.watch(catalogoDexProvider).value;
    final repo = ref.read(repositorioDexProvider);
    final bloqueado = shinyBloqueado(p, ajustes);
    final texto = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;

    Widget variante({required bool shiny}) {
      final meu = tenho.contains(chaveDex(p.id, shiny: shiny));
      final pos = catalogo?.posicao(p, shiny: shiny);
      final indisponivel = shiny && bloqueado;
      return Expanded(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: indisponivel
                  ? Icon(Icons.block, size: 48, color: cores.outlineVariant)
                  : CachedNetworkImage(
                      imageUrl: p.imagem(shiny: shiny),
                      placeholder: (_, _) => MiniaturaDex(
                        pokemon: p,
                        shiny: shiny,
                        tenho: true,
                        tamanho: 120,
                      ),
                      errorWidget: (_, _, _) => MiniaturaDex(
                        pokemon: p,
                        shiny: shiny,
                        tenho: true,
                        tamanho: 120,
                      ),
                      imageBuilder: (_, img) => meu
                          ? Image(image: img)
                          : ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0, 0, 0, 0.55, 0, //
                              ]),
                              child: Image(image: img),
                            ),
                    ),
            ),
            Text(shiny ? 'Shiny' : 'Regular', style: texto.titleSmall),
            if (indisponivel)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Não disponível',
                  style: texto.bodyMedium?.copyWith(color: cores.outline),
                ),
              )
            else
              FilterChip(
                label: Text(meu ? 'Tenho' : 'Falta'),
                selected: meu,
                onSelected: (v) => repo.definirTenho(p.id, shiny: shiny, tenho: v),
              ),
            if (pos != null && !indisponivel)
              Text(
                '${pos.nome}\nlinha ${pos.linha}, coluna ${pos.coluna}',
                textAlign: TextAlign.center,
                style: texto.bodySmall,
              ),
          ],
        ),
      );
    }

    final total = p.status.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.nome),
        actions: [
          PopupMenuButton<String>(
            onSelected: (op) => repo.definirShinyBloqueado(
              p.id,
              switch (op) {
                'bloquear' => true,
                'liberar' => false,
                _ => null,
              },
            ),
            itemBuilder: (_) => [
              if (!bloqueado)
                const PopupMenuItem(
                  value: 'bloquear',
                  child: Text('Marcar shiny como não disponível'),
                )
              else
                const PopupMenuItem(
                  value: 'liberar',
                  child: Text('Marcar shiny como disponível'),
                ),
              if (ajustes.containsKey(p.id))
                const PopupMenuItem(
                  value: 'padrao',
                  child: Text('Voltar ao padrão do catálogo'),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${p.numero} · ${p.tipos.join(' / ')}',
            style: texto.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              variante(shiny: false),
              const SizedBox(width: 12),
              variante(shiny: true),
            ],
          ),
          const SizedBox(height: 24),
          Text('Abilities', style: texto.titleSmall),
          const SizedBox(height: 4),
          Text(p.habilidades.join(', ')),
          if (p.habilidadeOculta != null)
            Text('Hidden: ${p.habilidadeOculta}'),
          const SizedBox(height: 20),
          Text('Base stats · total $total', style: texto.titleSmall),
          const SizedBox(height: 8),
          for (final (i, valor) in p.status.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(_nomesStatus[i])),
                  SizedBox(
                    width: 36,
                    child: Text('$valor', textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (valor / 200).clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text('Pode ir para (HOME)', style: texto.titleSmall),
          const SizedBox(height: 6),
          if (p.jogos.isEmpty)
            const Text('Nenhum dos jogos atuais.')
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final j in JogoDex.values)
                  if (p.jogos.contains(j)) Chip(label: Text(j.rotulo)),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver no Serebii'),
                  onPressed: () => launchUrl(
                    Uri.parse(p.urlSerebii),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver na Bulbapedia'),
                  onPressed: () => launchUrl(
                    Uri.parse(p.urlBulbapedia),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Dados: PokéAPI',
            textAlign: TextAlign.center,
            style: texto.bodySmall?.copyWith(color: cores.outline),
          ),
        ],
      ),
    );
  }
}
