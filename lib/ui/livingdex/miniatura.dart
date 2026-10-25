import 'package:flutter/material.dart';

import '../../livingdex/catalogo.dart';

/// Miniatura sem fundo: colorida se você tem, em preto e branco se falta.
class MiniaturaDex extends StatelessWidget {
  const MiniaturaDex({
    super.key,
    required this.pokemon,
    required this.shiny,
    required this.tenho,
    this.tamanho = 56,
  });

  final PokemonDex pokemon;
  final bool shiny;
  final bool tenho;
  final double tamanho;

  static const _cinza = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.55, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final imagem = Image.asset(
      pokemon.miniatura(shiny: shiny),
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox(
        width: tamanho,
        height: tamanho,
        child: Icon(
          Icons.catching_pokemon,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
    return tenho ? imagem : ColorFiltered(colorFilter: _cinza, child: imagem);
  }
}
