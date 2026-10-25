import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../livingdex/catalogo.dart';
import 'miniatura.dart';

class OpcaoRevisao {
  const OpcaoRevisao(
    this.id,
    this.rotulo,
    this.icone, {
    this.principal = false,
    this.discreta = false,
  });

  final String id;
  final String rotulo;
  final IconData icone;

  /// Botão cheio (a opção mais provável).
  final bool principal;

  /// Botão de texto (ação secundária).
  final bool discreta;
}

/// Painel de revisão de um espaço: o recorte do print ao lado do Pokémon
/// que o app entendeu, e as [opcoes]. Devolve o id da opção escolhida.
Future<String?> mostrarRevisao(
  BuildContext context, {
  required String titulo,
  required Future<Uint8List?> recorte,
  required PokemonDex? atual,
  required bool shiny,
  required List<OpcaoRevisao> opcoes,
  String? detalhe,
}) {
  final texto = Theme.of(context).textTheme;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: texto.titleMedium),
            if (detalhe != null) Text(detalhe, style: texto.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 104 / 88,
                        child: FutureBuilder<Uint8List?>(
                          future: recorte,
                          builder: (_, snap) => snap.data == null
                              ? Center(
                                  child: snap.connectionState ==
                                          ConnectionState.done
                                      ? const Icon(Icons.broken_image_outlined)
                                      : const CircularProgressIndicator(),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    snap.data!,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                        ),
                      ),
                      Text('No print', style: texto.labelMedium),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      if (atual == null)
                        const SizedBox(
                          height: 96,
                          child: Icon(Icons.help_outline, size: 40),
                        )
                      else
                        MiniaturaDex(
                          pokemon: atual,
                          shiny: shiny,
                          tenho: true,
                          tamanho: 96,
                        ),
                      Text(
                        atual == null ? 'Não identificado' : atual.nome,
                        textAlign: TextAlign.center,
                        style: texto.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final o in opcoes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: o.principal
                    ? FilledButton.icon(
                        icon: Icon(o.icone),
                        label: Text(o.rotulo),
                        onPressed: () => Navigator.pop(ctx, o.id),
                      )
                    : o.discreta
                        ? TextButton.icon(
                            icon: Icon(o.icone),
                            label: Text(o.rotulo),
                            onPressed: () => Navigator.pop(ctx, o.id),
                          )
                        : OutlinedButton.icon(
                            icon: Icon(o.icone),
                            label: Text(o.rotulo),
                            onPressed: () => Navigator.pop(ctx, o.id),
                          ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Busca para indicar qual Pokémon está no espaço.
Future<PokemonDex?> escolherPokemon(
  BuildContext context,
  CatalogoDex catalogo, {
  required bool shiny,
  bool formasPrimeiro = false,
}) {
  return Navigator.of(context).push<PokemonDex>(
    MaterialPageRoute(
      builder: (_) => _EscolherPokemonPage(
        catalogo: catalogo,
        shiny: shiny,
        formasPrimeiro: formasPrimeiro,
      ),
    ),
  );
}

class _EscolherPokemonPage extends StatefulWidget {
  const _EscolherPokemonPage({
    required this.catalogo,
    required this.shiny,
    required this.formasPrimeiro,
  });

  final CatalogoDex catalogo;
  final bool shiny;
  final bool formasPrimeiro;

  @override
  State<_EscolherPokemonPage> createState() => _EscolherPokemonPageState();
}

class _EscolherPokemonPageState extends State<_EscolherPokemonPage> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.catalogo;
    final base = widget.formasPrimeiro
        ? [...c.formas, ...c.nacionais]
        : c.pokemon;
    final q = _busca.trim().toLowerCase();
    final n = int.tryParse(q.replaceAll('#', ''));
    final lista = q.isEmpty
        ? base
        : [
            for (final p in base)
              if (n != null ? p.dex == n : p.nome.toLowerCase().contains(q)) p,
          ];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nome ou número',
            border: InputBorder.none,
          ),
          onChanged: (t) => setState(() => _busca = t),
        ),
      ),
      body: ListView.builder(
        itemCount: lista.length,
        itemExtent: 64,
        itemBuilder: (_, i) {
          final p = lista[i];
          return ListTile(
            leading: MiniaturaDex(pokemon: p, shiny: widget.shiny, tenho: true),
            title: Text(p.nome),
            subtitle: Text(p.numero),
            onTap: () => Navigator.pop(context, p),
          );
        },
      ),
    );
  }
}
