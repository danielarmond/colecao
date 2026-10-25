import 'package:flutter/material.dart';

import 'colecao_page.dart';
import 'livingdex/livingdex_page.dart';

/// Tela de abertura: duas seções separadas por um corte diagonal.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  // O corte vai de 58% da altura (esquerda) a 42% (direita).
  static const _esquerda = 0.58;
  static const _direita = 0.42;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: ClipPath(
                  clipper: _Corte(superior: true),
                  child: _Secao(
                    imagem: 'assets/inicio/midia_fisica.jpg',
                    alinhamento: const Alignment(0, -0.3),
                    titulo: 'Mídia Física',
                    posicao: Alignment(-0.85, -1 + _direita * 2 - 0.35),
                    degradeParaBaixo: true,
                    onTap: () => _abrir(context, const ColecaoPage()),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: _Corte(superior: false),
                  child: _Secao(
                    imagem: 'assets/inicio/livingdex.jpg',
                    alinhamento: Alignment.center,
                    titulo: 'LivingDex',
                    posicao: Alignment(0.85, -1 + _esquerda * 2 + 0.35),
                    degradeParaBaixo: false,
                    onTap: () => _abrir(context, const LivingDexPage()),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _LinhaCorte(),
                ),
              ),
              const Positioned(
                left: 20,
                top: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'DXA Coleções',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _abrir(BuildContext context, Widget pagina) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pagina));
  }
}

class _Secao extends StatelessWidget {
  const _Secao({
    required this.imagem,
    required this.alinhamento,
    required this.titulo,
    required this.posicao,
    required this.degradeParaBaixo,
    required this.onTap,
  });

  final String imagem;
  final Alignment alinhamento;
  final String titulo;
  final Alignment posicao;
  final bool degradeParaBaixo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(imagem, fit: BoxFit.cover, alignment: alinhamento),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: degradeParaBaixo
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  end: degradeParaBaixo
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  colors: const [Color(0x22000000), Color(0x99000000)],
                ),
              ),
            ),
            Align(
              alignment: posicao,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Corte extends CustomClipper<Path> {
  _Corte({required this.superior});

  final bool superior;

  @override
  Path getClip(Size s) {
    final e = s.height * InicioPage._esquerda;
    final d = s.height * InicioPage._direita;
    return superior
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(s.width, 0)
          ..lineTo(s.width, d)
          ..lineTo(0, e)
          ..close())
        : (Path()
          ..moveTo(0, e)
          ..lineTo(s.width, d)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close());
  }

  @override
  bool shouldReclip(_Corte old) => old.superior != superior;
}

class _LinhaCorte extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawLine(
      Offset(0, s.height * InicioPage._esquerda),
      Offset(s.width, s.height * InicioPage._direita),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_LinhaCorte old) => false;
}
