import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/banco.dart';
import '../../livingdex/catalogo.dart';
import '../../providers.dart';
import 'miniatura.dart';
import 'revisao_espaco.dart';

/// Lista "Aguardando validação": espaços de prints que ficaram para depois.
class ValidacaoPage extends ConsumerWidget {
  const ValidacaoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendencias = ref.watch(dexPendenciasProvider);
    final catalogo = ref.watch(catalogoDexProvider).value;
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Aguardando validação')),
      body: pendencias.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (lista) => lista.isEmpty || catalogo == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Nada para validar. Espaços removidos ou não conferidos '
                    'na carga por print aparecem aqui.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = lista[i];
                  final sugestao = p.sugestaoId == null
                      ? null
                      : catalogo.porId(p.sugestaoId!);
                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _validar(context, ref, p, catalogo),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                p.recorte,
                                width: 104,
                                height: 88,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.origem, style: texto.titleSmall),
                                  Text(p.shiny ? 'Shiny' : 'Regular'),
                                  if (sugestao != null)
                                    Text(
                                      'Sugestão: ${sugestao.nome}',
                                      style: texto.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            if (sugestao != null)
                              MiniaturaDex(
                                pokemon: sugestao,
                                shiny: p.shiny,
                                tenho: false,
                                tamanho: 44,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _validar(
    BuildContext context,
    WidgetRef ref,
    DexPendencia p,
    CatalogoDex catalogo,
  ) async {
    final repo = ref.read(repositorioDexProvider);
    final sugestao = p.sugestaoId == null ? null : catalogo.porId(p.sugestaoId!);
    final acao = await mostrarRevisao(
      context,
      titulo: p.origem,
      detalhe: p.shiny ? 'Shiny' : 'Regular',
      recorte: Future<Uint8List?>.value(p.recorte),
      atual: sugestao,
      shiny: p.shiny,
      opcoes: [
        if (sugestao != null)
          OpcaoRevisao('certo', 'É ${sugestao.nome}: marcar como tenho',
              Icons.check,
              principal: true),
        const OpcaoRevisao('escolher', 'Escolher o Pokémon', Icons.search),
        const OpcaoRevisao(
          'remover',
          'Remover da lista Validação',
          Icons.delete_outline,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (acao) {
      case 'certo':
        await repo.resolverPendencia(p, pokemonId: sugestao!.id);
      case 'escolher':
        final escolhido = await escolherPokemon(
          context,
          catalogo,
          shiny: p.shiny,
          formasPrimeiro: sugestao?.formaExtra ?? false,
        );
        if (escolhido != null) {
          await repo.resolverPendencia(p, pokemonId: escolhido.id);
        }
      case 'remover':
        await repo.resolverPendencia(p);
    }
  }
}
