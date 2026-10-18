import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rawg.dart';
import '../providers.dart';
import 'capa.dart';

/// Busca um jogo na RAWG e devolve o escolhido (ou null se voltar).
class BuscaRawgPage extends ConsumerStatefulWidget {
  const BuscaRawgPage({super.key, this.termoInicial = ''});

  final String termoInicial;

  @override
  ConsumerState<BuscaRawgPage> createState() => _BuscaRawgPageState();
}

class _BuscaRawgPageState extends ConsumerState<BuscaRawgPage> {
  late final TextEditingController _termo;
  List<RawgJogo>? _resultados;
  String? _erro;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _termo = TextEditingController(text: widget.termoInicial);
    if (widget.termoInicial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
    }
  }

  @override
  void dispose() {
    _termo.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final termo = _termo.text.trim();
    if (termo.isEmpty) return;
    setState(() {
      _buscando = true;
      _erro = null;
    });
    try {
      final r = await ref.read(rawgProvider).buscar(termo);
      if (!mounted) return;
      setState(() => _resultados = r);
    } on RawgErro catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar na RAWG')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _termo,
              autofocus: widget.termoInicial.isEmpty,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                hintText: 'Nome do jogo',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscar,
                ),
              ),
            ),
          ),
          if (_buscando) const LinearProgressIndicator(),
          Expanded(
            child: _erro != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_erro!, textAlign: TextAlign.center),
                    ),
                  )
                : resultados == null
                    ? const SizedBox.shrink()
                    : resultados.isEmpty
                        ? const Center(child: Text('Nada encontrado.'))
                        : ListView.builder(
                            itemCount: resultados.length,
                            itemBuilder: (context, i) {
                              final r = resultados[i];
                              final plats =
                                  r.plataformas.map((p) => p.nome).join(', ');
                              return ListTile(
                                leading: Capa(url: r.capaUrl, tamanho: 56),
                                title: Text(r.nome),
                                subtitle: Text(
                                  [if (r.ano != null) '${r.ano}', plats]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => Navigator.pop(context, r),
                              );
                            },
                          ),
          ),
          const SafeArea(top: false, child: CreditoRawg()),
        ],
      ),
    );
  }
}
