import 'tipos.dart';

/// O que a tela de Estatísticas precisa de cada item.
typedef ItemEstatistica = ({
  String titulo,
  String plataforma,
  StatusItem status,
  int? valorCentavos,
  int? valorMercadoCentavos,
});

typedef PorPlataforma = ({
  String plataforma,
  int itens,
  int pagoCentavos,
  int mercadoCentavos,
});

/// Números da tela de Estatísticas. Contam só os itens que são seus
/// (Na Coleção e Aguardando); Na Fila e Ignorado ficam de fora.
class Estatisticas {
  const Estatisticas({
    required this.itens,
    required this.pagoCentavos,
    required this.itensComValor,
    required this.maisCaro,
    required this.mercadoCentavos,
    required this.itensComMercado,
    required this.pagoDosComMercado,
    required this.porPlataforma,
  });

  factory Estatisticas.calcular(Iterable<ItemEstatistica> todos) {
    final meus = todos.where((i) => i.status.ehMeu).toList();

    var pago = 0, comValor = 0, mercado = 0, comMercado = 0, pagoComparavel = 0;
    ItemEstatistica? maisCaro;
    final plataformas = <String, ({int itens, int pago, int mercado})>{};

    for (final i in meus) {
      final v = i.valorCentavos;
      final m = i.valorMercadoCentavos;
      if (v != null) {
        pago += v;
        comValor++;
        if (maisCaro == null || v > maisCaro.valorCentavos!) maisCaro = i;
      }
      if (m != null) {
        mercado += m;
        comMercado++;
        pagoComparavel += v ?? 0;
      }
      final p = plataformas[i.plataforma] ?? (itens: 0, pago: 0, mercado: 0);
      plataformas[i.plataforma] = (
        itens: p.itens + 1,
        pago: p.pago + (v ?? 0),
        mercado: p.mercado + (m ?? 0),
      );
    }

    final lista = [
      for (final e in plataformas.entries)
        (
          plataforma: e.key,
          itens: e.value.itens,
          pagoCentavos: e.value.pago,
          mercadoCentavos: e.value.mercado,
        ),
    ]..sort((a, b) {
        final porPago = b.pagoCentavos.compareTo(a.pagoCentavos);
        return porPago != 0 ? porPago : b.itens.compareTo(a.itens);
      });

    return Estatisticas(
      itens: meus.length,
      pagoCentavos: pago,
      itensComValor: comValor,
      maisCaro: maisCaro == null
          ? null
          : (titulo: maisCaro.titulo, valorCentavos: maisCaro.valorCentavos!),
      mercadoCentavos: mercado,
      itensComMercado: comMercado,
      pagoDosComMercado: pagoComparavel,
      porPlataforma: lista,
    );
  }

  /// Itens seus (Na Coleção + Aguardando).
  final int itens;

  final int pagoCentavos;
  final int itensComValor;
  final ({String titulo, int valorCentavos})? maisCaro;

  final int mercadoCentavos;
  final int itensComMercado;

  /// Soma do valor pago só dos itens que têm valor de mercado, para
  /// comparar coisas comparáveis.
  final int pagoDosComMercado;

  final List<PorPlataforma> porPlataforma;

  /// Média do valor pago entre os itens que têm valor.
  int? get mediaCentavos =>
      itensComValor == 0 ? null : (pagoCentavos / itensComValor).round();

  /// Mercado - pago, só entre itens com valor de mercado.
  int? get valorizacaoCentavos =>
      itensComMercado == 0 ? null : mercadoCentavos - pagoDosComMercado;
}
