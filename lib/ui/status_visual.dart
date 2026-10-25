import 'package:flutter/material.dart';

import '../domain/tipos.dart';

/// Ícone e cor de cada status, usados na lista e no formulário.
extension StatusVisual on StatusItem {
  IconData get icone => switch (this) {
        StatusItem.naColecao => Icons.check_circle,
        StatusItem.aguardando => Icons.local_shipping,
        StatusItem.naFila => Icons.bookmark_border,
        StatusItem.ignorado => Icons.block,
      };

  Color cor(ColorScheme cores) => switch (this) {
        StatusItem.naColecao => cores.primary,
        StatusItem.aguardando => cores.tertiary,
        StatusItem.naFila => cores.secondary,
        StatusItem.ignorado => cores.outline,
      };
}

/// Medalha de "Zerado", ao lado do nome do jogo.
class MedalhaZerado extends StatelessWidget {
  const MedalhaZerado({super.key, this.tamanho = 18});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Zerado',
      child: Icon(
        Icons.military_tech,
        size: tamanho,
        color: const Color(0xFFD4A017), // dourado, legível no claro e no escuro
      ),
    );
  }
}

/// Título com a medalha ao lado quando o jogo foi zerado.
class TituloComMedalha extends StatelessWidget {
  const TituloComMedalha({
    super.key,
    required this.titulo,
    required this.zerado,
    this.estilo,
    this.tamanhoMedalha = 18,
  });

  final String titulo;
  final bool zerado;
  final TextStyle? estilo;
  final double tamanhoMedalha;

  @override
  Widget build(BuildContext context) {
    if (!zerado) {
      return Text(titulo, style: estilo, overflow: TextOverflow.ellipsis);
    }
    return Row(
      children: [
        Flexible(
          child: Text(titulo, style: estilo, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 4),
        MedalhaZerado(tamanho: tamanhoMedalha),
      ],
    );
  }
}
