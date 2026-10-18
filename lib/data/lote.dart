import '../domain/regras.dart';
import '../domain/tipos.dart';
import 'rawg.dart';

/// Plataforma do app que tem correspondente na RAWG.
typedef PlataformaLote = ({String id, int rawgId, String nome});

/// Item que já existe no app, para não cadastrar de novo.
typedef ExistenteLote = ({
  String itemId,
  int? rawgId,
  String tituloBusca,
  String plataformaId,
  StatusItem status,
});

/// Um jogo da RAWG em uma plataforma do app.
class CandidatoLote {
  const CandidatoLote({
    required this.jogo,
    required this.plataforma,
    this.ano,
    this.existente,
  });

  final RawgJogo jogo;
  final PlataformaLote plataforma;
  final int? ano;

  /// Preenchido quando você já tem esse item (qualquer status menos Ignorado).
  final ExistenteLote? existente;

  bool get novo => existente == null;
  String get chave => '${jogo.id}|${plataforma.id}';
}

/// Cruza os jogos da RAWG com as plataformas escolhidas e com o que já está
/// no app:
/// - cada (jogo, plataforma) vira um candidato, sem repetição;
/// - plataforma fora da seleção, ou ano fora do intervalo, fica de fora;
/// - item que você marcou como Ignorado fica de fora (não volta);
/// - item que você já tem vem com [CandidatoLote.existente] preenchido.
List<CandidatoLote> montarCandidatos({
  required List<RawgJogo> jogos,
  required List<PlataformaLote> plataformas,
  required List<ExistenteLote> existentes,
  int? anoDe,
  int? anoAte,
}) {
  final porRawgPlat = {for (final p in plataformas) p.rawgId: p};

  ExistenteLote? procurar(RawgJogo j, PlataformaLote p) {
    final titulo = normalizarTitulo(j.nome);
    for (final e in existentes) {
      if (e.plataformaId != p.id) continue;
      if (e.rawgId == j.id) return e;
      if (e.rawgId == null && e.tituloBusca == titulo) return e;
    }
    return null;
  }

  final vistos = <String>{};
  final candidatos = <CandidatoLote>[];
  for (final j in jogos) {
    for (final rp in j.plataformas) {
      final p = porRawgPlat[rp.id];
      if (p == null) continue;

      final ano = j.anoEm(rp.id);
      if (anoDe != null && (ano == null || ano < anoDe)) continue;
      if (anoAte != null && (ano == null || ano > anoAte)) continue;

      final c = CandidatoLote(
        jogo: j,
        plataforma: p,
        ano: ano,
        existente: procurar(j, p),
      );
      if (!vistos.add(c.chave)) continue;
      if (c.existente?.status == StatusItem.ignorado) continue;
      candidatos.add(c);
    }
  }

  candidatos.sort((a, b) {
    final porAno = (a.ano ?? 9999).compareTo(b.ano ?? 9999);
    if (porAno != 0) return porAno;
    final porNome = a.jogo.nome.compareTo(b.jogo.nome);
    return porNome != 0 ? porNome : a.plataforma.nome.compareTo(b.plataforma.nome);
  });
  return candidatos;
}
