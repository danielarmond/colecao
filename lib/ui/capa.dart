import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Miniatura da capa (arte da RAWG). Sem URL, mostra o ícone recebido.
class Capa extends StatelessWidget {
  const Capa({
    super.key,
    required this.url,
    this.tamanho = 48,
    this.semCapa,
  });

  final String? url;
  final double tamanho;
  final Widget? semCapa;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final vazio = SizedBox(
      width: tamanho,
      height: tamanho,
      child: Center(
        child: semCapa ??
            Icon(Icons.videogame_asset_outlined, color: cores.outline),
      ),
    );
    final u = url;
    if (u == null) return vazio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: u,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: tamanho,
          height: tamanho,
          color: cores.surfaceContainerHighest,
        ),
        errorWidget: (_, _, _) => vazio,
      ),
    );
  }
}

/// Capa ocupando a largura da tela, no topo da tela do item. Um degradê
/// escuro no alto deixa legíveis o título e os botões sobre a imagem.
class CapaBanner extends StatelessWidget {
  const CapaBanner({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => ColoredBox(color: cores.surfaceContainerHighest),
          errorWidget: (_, _, _) => ColoredBox(
            color: cores.surfaceContainerHighest,
            child: Icon(Icons.videogame_asset_outlined, color: cores.outline),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Crédito exigido pelos termos da RAWG nas telas que usam seus dados.
class CreditoRawg extends StatelessWidget {
  const CreditoRawg({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => launchUrl(
        Uri.parse('https://rawg.io'),
        mode: LaunchMode.externalApplication,
      ),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('Dados e imagens: RAWG'),
    );
  }
}
