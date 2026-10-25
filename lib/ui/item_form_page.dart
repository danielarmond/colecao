import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/banco.dart';
import '../data/repositorio.dart';
import '../domain/notas.dart';
import '../domain/regras.dart';
import '../domain/tipos.dart';
import '../providers.dart';
import '../data/rawg.dart';
import 'busca_rawg_page.dart';
import 'capa.dart';
import 'dialogos.dart';
import 'status_visual.dart';

/// Cadastro manual (existente == null) ou edição de um item.
/// Na edição, título e plataforma ficam fixos: para trocar, exclua e cadastre.
class ItemFormPage extends ConsumerStatefulWidget {
  const ItemFormPage({super.key, this.existente, this.colecaoInicial});

  final ItemDetalhado? existente;

  /// No cadastro, já marca esta coleção (a aba aberta na tela inicial).
  final String? colecaoInicial;

  @override
  ConsumerState<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends ConsumerState<ItemFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _ano;
  late final TextEditingController _valor;
  late final TextEditingController _obs;

  String? _plataformaId;
  late StatusItem _status;
  Condicao? _condicao;
  DateTime? _dataChegada;
  bool _salvando = false;

  /// Coleções marcadas. Na edição, carregadas do banco no initState.
  late Set<String> _colecaoIds;

  /// Sua nota e condição saíram da tela; os valores antigos são mantidos.
  int? _nota;
  late bool _zerado;

  /// Jogo escolhido na RAWG nesta tela (ainda não gravado).
  RawgJogo? _rawg;
  String? _capaUrl;
  int? _rawgIdAtual;

  bool get _editando => widget.existente != null;

  /// Controla a cor do topo: branca sobre o banner, normal quando recolhido.
  final _rolagem = ScrollController();
  bool _bannerRecolhido = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _ano = TextEditingController(text: e?.ano?.toString() ?? '');
    _valor = TextEditingController(
      text: centavosParaCampo(e?.item.valorCentavos),
    );
    _obs = TextEditingController(text: e?.item.observacoes ?? '');
    _plataformaId = e?.plataforma.id;
    _status = e?.item.status ?? StatusItem.naColecao;
    _condicao = e?.item.condicao;
    _dataChegada = e?.item.dataChegada;
    _capaUrl = e?.capaUrl;
    _nota = e?.item.nota;
    _zerado = e?.item.zerado ?? false;
    _rawgIdAtual = e?.jogo.rawgId;
    final vinculos = ref.read(vinculosProvider).value ?? const {};
    _colecaoIds = e != null
        ? {...?vinculos[e.item.id]}
        : {if (widget.colecaoInicial != null) widget.colecaoInicial!};
  }

  Future<void> _novaColecao() async {
    final nome = await pedirNome(
      context,
      titulo: 'Nova coleção',
      dica: 'Nova coleção',
      confirmar: 'Criar',
    );
    if (nome == null) return;
    final id = await ref.read(repositorioProvider).criarColecao(nome);
    if (!mounted) return;
    setState(() => _colecaoIds.add(id));
  }

  Future<void> _buscarNaRawg(List<Plataforma> plataformas) async {
    final r = await Navigator.of(context).push<RawgJogo>(
      MaterialPageRoute(
        builder: (_) => BuscaRawgPage(termoInicial: _titulo.text.trim()),
      ),
    );
    if (r == null || !mounted) return;

    setState(() {
      _rawg = r;
      _capaUrl = r.capaUrl;
      if (_editando) return; // na edição, só vincula: título e plataforma ficam

      _titulo.text = r.nome;
      // Pré-seleciona a plataforma se só uma das da RAWG existir no app.
      final idsRawg = {for (final p in r.plataformas) p.id};
      final locais =
          plataformas.where((p) => idsRawg.contains(p.rawgId)).toList();
      if (_plataformaId == null && locais.length == 1) {
        _plataformaId = locais.single.id;
      }
      _preencherAno(plataformas);
    });
  }

  /// Usa o ano da RAWG na plataforma escolhida, se o campo estiver vazio.
  void _preencherAno(List<Plataforma> plataformas) {
    final r = _rawg;
    if (r == null || _ano.text.trim().isNotEmpty) return;
    final rawgPlat = plataformas
        .where((p) => p.id == _plataformaId)
        .map((p) => p.rawgId)
        .firstOrNull;
    final ano = r.anoEm(rawgPlat);
    if (ano != null) _ano.text = '$ano';
  }

  @override
  void dispose() {
    _rolagem.dispose();
    _titulo.dispose();
    _ano.dispose();
    _valor.dispose();
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plataformas = ref.watch(plataformasProvider).value ?? const [];
    final colecoes = ref.watch(colecoesProvider).value ?? const [];
    final cores = Theme.of(context).colorScheme;
    final e = widget.existente;

    final capa = _capaUrl;
    // Jogo atualizado do banco (a nota da comunidade pode ter mudado depois
    // que a tela abriu, ex.: "Atualizar notas da comunidade").
    var jogoVivo = e?.jogo;
    if (e != null) {
      for (final i in ref.watch(itensProvider).value ?? const <ItemDetalhado>[]) {
        if (i.item.id == e.item.id) jogoVivo = i.jogo;
      }
    }
    final notaComunidade = formatarNotaComunidade(
      _rawg?.nota ?? jogoVivo?.notaComunidade,
      _rawg != null ? _rawg!.votos : jogoVivo?.votosComunidade,
    );
    final vinculado = _rawg != null || _rawgIdAtual != null;
    final alturaBanner =
        (MediaQuery.sizeOf(context).width * 2 / 3).clamp(160.0, 300.0)
            .toDouble();
    // Texto branco enquanto o banner está aberto atrás da barra.
    final sobreBanner = capa != null && !_bannerRecolhido;
    final estiloTopo = TextButton.styleFrom(
      foregroundColor: sobreBanner ? Colors.white : null,
    );

    final acoes = <Widget>[
      if (e != null && e.item.status == StatusItem.naFila)
        TextButton(
          style: estiloTopo,
          onPressed: () => _mudarStatus(StatusItem.ignorado),
          child: const Text('Remover da fila'),
        ),
      if (e != null && e.item.status == StatusItem.ignorado)
        TextButton(
          style: estiloTopo,
          onPressed: () => _mudarStatus(StatusItem.naFila),
          child: const Text('Restaurar'),
        ),
      if (e != null)
        IconButton(
          tooltip: 'Duplicar jogo',
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: _duplicar,
        ),
      if (e != null)
        IconButton(
          tooltip: 'Excluir',
          icon: const Icon(Icons.delete_outline),
          onPressed: _excluir,
        ),
    ];

    return Scaffold(
      body: Form(
        key: _form,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            final recolhido =
                n.metrics.pixels > alturaBanner - kToolbarHeight - 24;
            if (recolhido != _bannerRecolhido) {
              setState(() => _bannerRecolhido = recolhido);
            }
            return false;
          },
          child: CustomScrollView(
            controller: _rolagem,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: capa == null ? null : alturaBanner,
                foregroundColor: sobreBanner ? Colors.white : null,
                title: e == null
                    ? const Text('Novo item')
                    : TituloComMedalha(
                        titulo: e.titulo,
                        zerado: _zerado,
                        tamanhoMedalha: 22,
                      ),
                actions: acoes,
                flexibleSpace: capa == null
                    ? null
                    : FlexibleSpaceBar(background: CapaBanner(url: capa)),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
            OutlinedButton.icon(
              onPressed: () => _buscarNaRawg(plataformas),
              icon: const Icon(Icons.travel_explore),
              label: Text(
                _editando
                    ? (_rawgIdAtual == null && _rawg == null
                        ? 'Vincular à RAWG'
                        : 'Trocar vínculo RAWG')
                    : 'Buscar na RAWG',
              ),
            ),
            if (_rawg != null)
              Text(
                'RAWG: ${_rawg!.nome}',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (_rawgIdAtual == null)
              Text(
                'Sem vínculo com a RAWG',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (vinculado)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Nota da comunidade (RAWG): '
                  '${notaComunidade ?? 'sem nota (sem votos ou ainda não '
                      'atualizada)'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titulo,
              decoration: InputDecoration(
                labelText: _editando ? 'Nome de exibição' : 'Título',
                helperText: _editando
                    ? 'Título do jogo: ${e!.jogo.titulo}'
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
            ),
            const SizedBox(height: 12),
            if (_editando)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Plataforma',
                  enabled: false,
                ),
                child: Text(e!.plataforma.nome),
              )
            else
              DropdownButtonFormField<String>(
                // Recria o campo quando a busca na RAWG pré-seleciona.
                key: ValueKey('plataforma-$_plataformaId'),
                initialValue: _plataformaId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Plataforma'),
                items: [
                  for (final p in plataformas)
                    DropdownMenuItem(value: p.id, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() {
                  _plataformaId = v;
                  _preencherAno(plataformas);
                }),
                validator: (v) => v == null ? 'Escolha a plataforma' : null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ano,
              decoration: const InputDecoration(
                labelText: 'Ano de lançamento na plataforma',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final ano = int.tryParse(v.trim());
                return (ano == null || ano < 1970 || ano > 2100)
                    ? 'Ano inválido'
                    : null;
              },
            ),
            const SizedBox(height: 20),
            Text('Coleções', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in colecoes)
                  FilterChip(
                    label: Text(c.nome),
                    selected: _colecaoIds.contains(c.id),
                    onSelected: (marcado) => setState(() {
                      marcado ? _colecaoIds.add(c.id) : _colecaoIds.remove(c.id);
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nova coleção'),
                  onPressed: _novaColecao,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Status', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in StatusItem.values)
                  ChoiceChip(
                    avatar: Icon(s.icone, size: 18, color: s.cor(cores)),
                    label: Text(s.rotulo),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _zerado,
              onChanged: (v) => setState(() => _zerado = v ?? false),
              title: const Text('Zerado'),
              secondary: _zerado ? const MedalhaZerado(tamanho: 26) : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valor,
              decoration: const InputDecoration(
                labelText: 'Valor pago',
                prefixText: 'R\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                try {
                  lerValorCentavos(v ?? '');
                  return null;
                } on FormatException {
                  return 'Valor inválido';
                }
              },
            ),
            const SizedBox(height: 12),
            _CampoData(
              rotulo: _status == StatusItem.aguardando
                  ? 'Chegada prevista'
                  : 'Data de chegada',
              data: _dataChegada,
              onChanged: (d) => setState(() => _dataChegada = d),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obs,
              decoration: const InputDecoration(labelText: 'Observações'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : () => _salvar(plataformas),
              child: Text(_salvando ? 'Salvando…' : 'Salvar'),
            ),
            if (_capaUrl != null) const CreditoRawg(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _salvar(List<Plataforma> plataformas) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);

    final repo = ref.read(repositorioProvider);
    final ano = int.tryParse(_ano.text.trim());
    final valor = lerValorCentavos(_valor.text);
    final e = widget.existente;
    final rawg = _rawg;

    try {
      if (e != null) {
        if (rawg != null) {
          await repo.vincularRawg(
            e.jogo.id,
            rawg.id,
            rawg.capaUrl,
            notaComunidade: rawg.nota,
            votosComunidade: rawg.votos,
          );
        }
        await repo.atualizarItem(
          e,
          ano: ano,
          status: _status,
          valorCentavos: valor,
          dataChegada: _dataChegada,
          condicao: _condicao,
          observacoes: _obs.text,
          tituloExibicao: _titulo.text,
          nota: _nota,
          zerado: _zerado,
        );
        await repo.definirColecoes(e.item.id, _colecaoIds);
      } else {
        await repo.adicionarItem(
          titulo: _titulo.text,
          plataforma: plataformas.firstWhere((p) => p.id == _plataformaId),
          ano: ano,
          status: _status,
          valorCentavos: valor,
          dataChegada: _dataChegada,
          condicao: _condicao,
          observacoes: _obs.text,
          colecaoIds: _colecaoIds,
          rawgId: rawg?.id,
          capaUrl: rawg?.capaUrl,
          notaComunidade: rawg?.nota,
          votosComunidade: rawg?.votos,
          nota: _nota,
          zerado: _zerado,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ItemDuplicadoException catch (erro) {
      _avisar(erro.toString());
    } catch (erro) {
      _avisar('Não foi possível salvar: $erro');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Cria outro item do mesmo jogo e plataforma, com outro nome de
  /// exibição (ex.: "Pokémon Violet" a partir de "Pokémon Scarlet").
  Future<void> _duplicar() async {
    final e = widget.existente!;
    final nome = await pedirNome(
      context,
      titulo: 'Duplicar jogo',
      inicial: e.titulo,
      dica: 'Nome de exibição da cópia',
      confirmar: 'Duplicar',
    );
    if (nome == null || !mounted) return;
    await ref.read(repositorioProvider).duplicarItem(
          e,
          nome: nome,
          colecaoIds: _colecaoIds,
        );
    if (!mounted) return;
    // O aviso aparece na tela da lista, depois de voltar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$nome" criado com o status e as coleções deste item.'),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _mudarStatus(StatusItem status) async {
    await ref
        .read(repositorioProvider)
        .mudarStatus(widget.existente!.item.id, status);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _excluir() async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir item?',
      mensagem: 'O item sai do app e das contas. Se quiser só tirar da '
          'fila, use "Remover da fila".',
      botao: 'Excluir',
    );
    if (!ok) return;
    await ref.read(repositorioProvider).excluirItem(widget.existente!.item.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({
    required this.rotulo,
    required this.data,
    required this.onChanged,
  });

  final String rotulo;
  final DateTime? data;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        suffixIcon: data == null
            ? null
            : IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              ),
      ),
      child: InkWell(
        onTap: () async {
          final escolhida = await showDatePicker(
            context: context,
            initialDate: data ?? DateTime.now(),
            firstDate: DateTime(1980),
            lastDate: DateTime(2100),
          );
          if (escolhida != null) onChanged(escolhida);
        },
        child: Text(
          data == null ? 'Toque para escolher' : DateFormat('dd/MM/yyyy').format(data!),
        ),
      ),
    );
  }
}
