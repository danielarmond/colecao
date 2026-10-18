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
