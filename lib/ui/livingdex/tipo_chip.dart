import 'package:flutter/material.dart';

/// Cores dos tipos (as usuais nos jogos), para os selos e os filtros.
const coresTipo = <String, Color>{
  'Normal': Color(0xFFA8A77A),
  'Fire': Color(0xFFEE8130),
  'Water': Color(0xFF6390F0),
  'Electric': Color(0xFFF7D02C),
  'Grass': Color(0xFF7AC74C),
  'Ice': Color(0xFF96D9D6),
  'Fighting': Color(0xFFC22E28),
  'Poison': Color(0xFFA33EA1),
  'Ground': Color(0xFFE2BF65),
  'Flying': Color(0xFFA98FF3),
  'Psychic': Color(0xFFF95587),
  'Bug': Color(0xFFA6B91A),
  'Rock': Color(0xFFB6A136),
  'Ghost': Color(0xFF735797),
  'Dragon': Color(0xFF6F35FC),
  'Dark': Color(0xFF705746),
  'Steel': Color(0xFFB7B7CE),
  'Fairy': Color(0xFFD685AD),
};

Color corTipo(String tipo) => coresTipo[tipo] ?? Colors.grey;

/// Selo colorido de um tipo (ex.: "Fire").
class TipoChip extends StatelessWidget {
  const TipoChip(this.tipo, {super.key, this.pequeno = false});

  final String tipo;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    final cor = corTipo(tipo);
    final texto = cor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pequeno ? 6 : 10,
        vertical: pequeno ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tipo,
        style: TextStyle(
          color: texto,
          fontSize: pequeno ? 11 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Os tipos de um Pokémon lado a lado.
class TiposDex extends StatelessWidget {
  const TiposDex(this.tipos, {super.key, this.pequeno = true});

  final List<String> tipos;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [for (final t in tipos) TipoChip(t, pequeno: pequeno)],
    );
  }
}
