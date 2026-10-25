/// Como mostrar a sua nota. Ela é sempre guardada de 0 a 10.
enum EscalaNota {
  numero('Número (0 a 10)'),
  tier('Tier (SS a E)');

  const EscalaNota(this.rotulo);

  final String rotulo;

  static EscalaNota deTexto(String? t) =>
      EscalaNota.values.where((e) => e.name == t).firstOrNull ??
      EscalaNota.numero;
}

/// Tiers do melhor para o pior, com a nota que cada um grava.
const tiers = <(String tier, int nota)>[
  ('SS', 10),
  ('S', 9),
  ('A', 8),
  ('B', 7),
  ('C', 6),
  ('D', 5),
  ('E', 4),
];

/// 10 = SS, 9 = S, 8 = A, 7 = B, 6 = C, 5 = D, 4 ou menos = E.
String tierDaNota(int nota) {
  for (final (tier, valor) in tiers) {
    if (nota >= valor) return tier;
  }
  return 'E';
}

int? notaDoTier(String tier) {
  for (final (t, valor) in tiers) {
    if (t == tier.trim().toUpperCase()) return valor;
  }
  return null;
}

/// "8" ou "A", conforme a escala. Null quando não há nota.
String? formatarNota(int? nota, EscalaNota escala) {
  if (nota == null) return null;
  return escala == EscalaNota.tier ? tierDaNota(nota) : '$nota';
}

/// "★ 4,4 (501)". Null quando a RAWG não tem nota (0 votos).
String? formatarNotaComunidade(double? nota, int? votos) {
  if (nota == null || nota <= 0) return null;
  final n = nota.toStringAsFixed(1).replaceAll('.', ',');
  return votos == null || votos == 0 ? '★ $n' : '★ $n ($votos)';
}

/// Lê a nota do CSV: número de 0 a 10 ou tier (SS a E).
int? lerNota(String? texto) {
  final t = texto?.trim();
  if (t == null || t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n != null) return (n >= 0 && n <= 10) ? n : null;
  return notaDoTier(t);
}
