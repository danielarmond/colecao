import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/banco.dart';
import '../data/lote.dart';
import '../data/rawg.dart';
import '../providers.dart';
import 'busca_rawg_page.dart';
import 'capa.dart';
import 'dialogos.dart';
import 'status_visual.dart';

enum _Modo { nome, serie }

/// Adiciona à Wishlist (Na Fila) de uma coleção os jogos da RAWG que batem
/// com os filtros. Desmarcados viram Ignorado; o que você já tem só entra
/// na coleção.
class LoteWishlistPage extends ConsumerStatefulWidget {
  const LoteWishlistPage({super.key, required this.colecao});

  final Colecao colecao;

  @override
  ConsumerState<LoteWishlistPage> createState() => _LoteWishlistPageState();
}

class _LoteWishlistPageState extends ConsumerState<LoteWishlistPage> {
  late _Modo _modo;
  late final TextEditingController _termo;
  final _anoDe = TextEditingController();
  final _anoAte = TextEditingController();

  /// Jogo-base da série: o objeto (se escolhido agora) ou só o id salvo.
  RawgJogo? _semente;
  int? _sementeId;

  /// Plataformas do app (ids) escolhidas. Vazio = todas.
  late Set<String> _plataformas;

  List<CandidatoLote>? _candidatos;
  final Set<String> _desmarcados = {};
  bool _buscando = false;
  bool _aplicando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _termo = TextEditingController(text: widget.colecao.nome);
    _sementeId = widget.colecao.rawgJogoSemente;
    _modo = _sementeId != null ? _Modo.serie : _Modo.nome;

    // Começa com as plataformas que já aparecem nesta coleção.
    final itens = ref.read(itensProvider).value ?? const [];
    final vinculos = ref.read(vinculosProvider).value ?? const {};
    _plataformas = {
      for (final i in itens)
        if (vinculos[i.item.id]?.contains(widget.colecao.id) ?? false)
          if (i.plataforma.rawgId != null) i.plataforma.id,
    };
  }

  @override
  void dispose() {
    _termo.dispose();
    _anoDe.dispose();
    _anoAte.dispose();
    super.dispose();
  }

  List<PlataformaLote> _plataformasLote(List<Plataforma> todas) => [
        for (final p in todas)
          if (p.rawgId != null &&
              (_plataformas.isEmpty || _plataformas.contains(p.id)))
            (id: p.id, rawgId: p.rawgId!, nome: p.nome),
      ];

  Future<void> _escolherSemente() async {
    final r = await Navigator.of(context).push<RawgJogo>(
      MaterialPageRoute(
        builder: (_) => BuscaRawgPage(termoInicial: widget.colecao.nome),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _semente = r;
      _sementeId = r.id;
      _candidatos = null;
    });
  }

  Future<void> _buscar(List<Plataforma> todas) async {
    final rawg = ref.read(rawgProvider);
    final repo = ref.read(repositorioProvider);
    final plats = _plataformasLote(todas);

    setState(() {
      _buscando = true;
      _erro = null;
    });
    try {
      final List<RawgJogo> jogos;
      if (_modo == _Modo.serie) {
        final id = _sementeId;
        if (id == null) throw const RawgErro('Escolha o jogo-base da série.');
        final base = _semente ?? await rawg.detalhes(id);
        jogos = [base, ...await rawg.serie(id)];
        await repo.salvarSemente(widget.colecao.id, id);
        _semente = base;
      } else {
        final termo = _termo.text.trim();
        if (termo.isEmpty) throw const RawgErro('Digite um nome para buscar.');
        jogos = await rawg.buscarVarias(
          termo,
          plataformas: {for (final p in plats) p.rawgId},
        );
      }

      final itens = ref.read(itensProvider).value ?? const [];
      final candidatos = montarCandidatos(
        jogos: jogos,
        plataformas: plats,
        anoDe: int.tryParse(_anoDe.text.trim()),
        anoAte: int.tryParse(_anoAte.text.trim()),
        existentes: [
          for (final i in itens)
            (
              itemId: i.item.id,
              rawgId: i.jogo.rawgId,
              tituloBusca: i.jogo.tituloBusca,
              plataformaId: i.plataforma.id,
              status: i.item.status,
            ),
        ],
      );
      if (!mounted) return;
      setState(() {
        _candidatos = candidatos;
        _desmarcados.clear();
      });
    } on RawgErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha na busca: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _aplicar(List<Plataforma> todas) async {
    final candidatos = _candidatos;
    if (candidatos == null) return;
    final novos = candidatos.where((c) => c.novo).toList();
    final marcados =
        novos.where((c) => !_desmarcados.contains(c.chave)).length;
    final ignorados = novos.length - marcados;
    final jaTem = candidatos.length - novos.length;

    final ok = await confirmar(
      context,
      titulo: 'Adicionar à Wishlist',
      mensagem: [
        '$marcados itens entram na Wishlist (Na Fila).',
        if (ignorados > 0)
          '$ignorados desmarcados entram como Ignorado e não voltam nas '
              'próximas buscas.',
        if (jaTem > 0) '$jaTem que você já tem passam a fazer parte desta coleção.',
      ].join('\n\n'),
      botao: 'Adicionar',
    );
    if (!ok || !mounted) return;

    setState(() => _aplicando = true);
    try {
      final r = await ref.read(repositorioProvider).aplicarLote(
            colecaoId: widget.colecao.id,
            candidatos: candidatos,
            desmarcados: _desmarcados,
            plataformas: todas,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${r.naFila} na Wishlist, ${r.ignorados} ignorados, '
            '${r.incluidos} já seus incluídos em "${widget.colecao.nome}".',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível adicionar: $e');
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(plataformasProvider).value ?? const <Plataforma>[];
    final comRawg = todas.where((p) => p.rawgId != null).toList();
    final candidatos = _candidatos;
    final novos = candidatos?.where((c) => c.novo).toList() ?? const [];
    final marcados =
        novos.where((c) => !_desmarcados.contains(c.chave)).length;
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Lote · ${widget.colecao.nome}')),
      bottomNavigationBar: candidatos == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed: _aplicando || candidatos.isEmpty
                      ? null
                      : () => _aplicar(todas),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(
                    _aplicando
                        ? 'Adicionando…'
                        : 'Adicionar $marcados à Wishlist',
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Modo>(
            segments: const [
              ButtonSegment(
                value: _Modo.nome,
                label: Text('Por nome'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: _Modo.serie,
                label: Text('Série de um jogo'),
                icon: Icon(Icons.account_tree_outlined),
              ),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() {
              _modo = s.first;
              _candidatos = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_modo == _Modo.nome)
            TextField(
              controller: _termo,
              decoration: const InputDecoration(
                labelText: 'Nome contém',
                helperText: 'Ex.: "Zelda" traz todos os jogos com Zelda no '
                    'título',
                border: OutlineInputBorder(),
              ),
            )
          else
            Row(
              children: [
                Capa(url: _semente?.capaUrl, tamanho: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _semente?.nome ??
                        (_sementeId == null
                            ? 'Nenhum jogo-base escolhido'
                            : 'Jogo-base salvo (RAWG #$_sementeId)'),
                  ),
                ),
                TextButton(
                  onPressed: _escolherSemente,
                  child: Text(_sementeId == null ? 'Escolher' : 'Trocar'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            _plataformas.isEmpty
                ? 'Plataformas (nenhuma marcada = todas)'
                : 'Plataformas',
            style: texto.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in comRawg)
                FilterChip(
                  label: Text(p.sigla),
                  tooltip: p.nome,
                  selected: _plataformas.contains(p.id),
                  onSelected: (m) => setState(() {
                    m ? _plataformas.add(p.id) : _plataformas.remove(p.id);
                    _candidatos = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _anoDe,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ano de',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _anoAte,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ano até',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _buscando ? null : () => _buscar(todas),
            icon: const Icon(Icons.travel_explore),
            label: Text(_buscando ? 'Buscando na RAWG…' : 'Buscar jogos'),
          ),
          if (_buscando) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (candidatos != null) ...[
            const Divider(height: 32),
            if (candidatos.isEmpty)
              const Text('Nenhum jogo encontrado com esses filtros.')
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${novos.length} novos · '
                      '${candidatos.length - novos.length} já são seus',
                      style: texto.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_desmarcados.clear),
                    child: const Text('Marcar todos'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _desmarcados.addAll(novos.map((c) => c.chave));
                    }),
                    child: const Text('Nenhum'),
                  ),
                ],
              ),
              Text(
                'Desmarcados viram Ignorado. Relançamentos digitais (ex.: '
                'Virtual Console) costumam aparecer aqui: desmarque-os.',
                style: texto.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final c in candidatos) _linha(c),
            ],
            const CreditoRawg(),
          ],
        ],
      ),
    );
  }

  Widget _linha(CandidatoLote c) {
    final subtitulo =
        [c.plataforma.nome, if (c.ano != null) '${c.ano}'].join(' · ');
    final existente = c.existente;
    if (existente != null) {
      final cores = Theme.of(context).colorScheme;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Capa(url: c.jogo.capaUrl),
        title: Text(c.jogo.nome),
        subtitle: Text('$subtitulo · já é seu (${existente.status.rotulo})'),
        trailing: Icon(existente.status.icone,
            color: existente.status.cor(cores)),
      );
    }
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Capa(url: c.jogo.capaUrl),
      title: Text(c.jogo.nome),
      subtitle: Text(subtitulo),
      value: !_desmarcados.contains(c.chave),
      onChanged: (v) => setState(() {
        v == true ? _desmarcados.remove(c.chave) : _desmarcados.add(c.chave);
      }),
    );
  }
}
