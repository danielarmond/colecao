import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/banco.dart';
import '../data/repositorio.dart';
import '../domain/regras.dart';
import '../domain/tipos.dart';
import '../providers.dart';
import 'backup_page.dart';
import 'capa.dart';
import 'dialogos.dart';
import 'item_form_page.dart';
import 'lote_wishlist_page.dart';
import 'status_visual.dart';

/// Filtro de status da lista. "Ativos" esconde só os ignorados.
enum FiltroStatus {
  ativos('Ativos', null),
  naColecao('Na Coleção', StatusItem.naColecao),
  aguardando('Aguardando', StatusItem.aguardando),
  naFila('Na Fila', StatusItem.naFila),
  ignorados('Ignorados', StatusItem.ignorado);

  const FiltroStatus(this.rotulo, this.status);

  final String rotulo;
  final StatusItem? status;

  bool aceita(StatusItem s) =>
      status == null ? s != StatusItem.ignorado : s == status;
}

class ColecaoPage extends ConsumerStatefulWidget {
  const ColecaoPage({super.key});

  @override
  ConsumerState<ColecaoPage> createState() => _ColecaoPageState();
}

class _ColecaoPageState extends ConsumerState<ColecaoPage> {
  /// Aba aberta: null = "Todos".
  String? _colecaoId;
  FiltroStatus _filtro = FiltroStatus.ativos;
  String? _plataformaId;
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final itens = ref.watch(itensProvider);
    final plataformas = ref.watch(plataformasProvider).value ?? const [];
    final colecoes = ref.watch(colecoesProvider).value ?? const <Colecao>[];
    final vinculos = ref.watch(vinculosProvider).value ?? const {};

    // Se a coleção aberta foi excluída, volta para "Todos".
    final aberta = colecoes.where((c) => c.id == _colecaoId).firstOrNull;
    final indice = aberta == null ? 0 : colecoes.indexOf(aberta) + 1;

    return DefaultTabController(
      // Recria as abas quando coleções são criadas, renomeadas ou excluídas.
      key: ValueKey(colecoes.map((c) => '${c.id}:${c.nome}').join('|')),
      length: colecoes.length + 1,
      initialIndex: indice,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coleção'),
          actions: [_menu(context, aberta)],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (i) => setState(
              () => _colecaoId = i == 0 ? null : colecoes[i - 1].id,
            ),
            tabs: [
              const Tab(text: 'Todos'),
              for (final c in colecoes) Tab(text: c.nome),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(context, colecao: aberta),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar'),
        ),
        body: itens.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
          data: (todos) {
            final daAba = aberta == null
                ? todos
                : todos
                    .where((i) => vinculos[i.item.id]?.contains(aberta.id) ?? false)
                    .toList();
            // O resumo respeita aba, plataforma e busca; não o filtro de status.
            final recorte = daAba.where(_noRecorte).toList();
            final resumo = ResumoColecao.calcular(
              recorte.map(
                (i) => (
                  status: i.item.status,
                  valorCentavos: i.item.valorCentavos,
                ),
              ),
            );
            final visiveis =
                recorte.where((i) => _filtro.aceita(i.item.status)).toList();
            final usadas = {for (final i in daAba) i.plataforma.id};

            return Column(
              children: [
                _ResumoCard(resumo: resumo),
                _Filtros(
                  filtro: _filtro,
                  onFiltro: (f) => setState(() => _filtro = f),
                  plataformas:
                      plataformas.where((p) => usadas.contains(p.id)).toList(),
                  plataformaId: _plataformaId,
                  onPlataforma: (id) => setState(() => _plataformaId = id),
                  onBusca: (t) => setState(() => _busca = t),
                ),
                Expanded(
                  child: visiveis.isEmpty
                      ? _ListaVazia(
                          semItens: daAba.isEmpty,
                          colecao: aberta?.nome,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: visiveis.length,
                          itemBuilder: (context, i) => _ItemTile(
                            item: visiveis[i],
                            onTap: () => _abrirFormulario(
                              context,
                              existente: visiveis[i],
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, Colecao? aberta) {
    return PopupMenuButton<String>(
      onSelected: (opcao) => _acaoMenu(context, opcao, aberta),
      itemBuilder: (_) => [
        if (aberta != null) ...[
          const PopupMenuItem(
            value: 'lote',
            child: ListTile(
              leading: Icon(Icons.playlist_add),
              title: Text('Adicionar em lote à Wishlist'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'renomear',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Renomear coleção'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'excluir',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Excluir coleção'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'nova',
          child: ListTile(
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('Nova coleção'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'backup',
          child: ListTile(
            leading: Icon(Icons.backup_outlined),
            title: Text('Backup e planilha'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _acaoMenu(
    BuildContext context,
    String opcao,
    Colecao? aberta,
  ) async {
    final repo = ref.read(repositorioProvider);
    switch (opcao) {
      case 'backup':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BackupPage()),
        );
      case 'nova':
        {
          final nome = await pedirNome(
            context,
            titulo: 'Nova coleção',
            dica: 'Pokémon',
            confirmar: 'Criar',
          );
          if (nome == null) return;
          final id = await repo.criarColecao(nome);
          if (mounted) setState(() => _colecaoId = id);
        }
      case 'renomear':
        {
          if (aberta == null) return;
          final nome = await pedirNome(
            context,
            titulo: 'Renomear coleção',
            inicial: aberta.nome,
          );
          if (nome != null) await repo.renomearColecao(aberta.id, nome);
        }
      case 'excluir':
        {
          if (aberta == null) return;
          final ok = await confirmar(
            context,
            titulo: 'Excluir "${aberta.nome}"?',
            mensagem: 'Só a aba é excluída. Os itens continuam no app, na '
                'aba Todos e nas outras coleções em que estiverem.',
            botao: 'Excluir',
          );
          if (!ok) return;
          await repo.excluirColecao(aberta.id);
          if (mounted) setState(() => _colecaoId = null);
        }
      case 'lote':
        if (aberta == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LoteWishlistPage(colecao: aberta),
          ),
        );
    }
  }

  bool _noRecorte(ItemDetalhado i) {
    if (_plataformaId != null && i.plataforma.id != _plataformaId) {
      return false;
    }
    if (_busca.isNotEmpty &&
        !i.jogo.tituloBusca.contains(normalizarTitulo(_busca))) {
      return false;
    }
    return true;
  }

  void _abrirFormulario(
    BuildContext context, {
    ItemDetalhado? existente,
    Colecao? colecao,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemFormPage(
          existente: existente,
          colecaoInicial: colecao?.id,
        ),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({required this.resumo});

  final ResumoColecao resumo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final progresso = resumo.progresso;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Numero(
                    rotulo: 'Itens',
                    valor: '${resumo.meus}',
                  ),
                ),
                Expanded(
                  child: _Numero(
                    rotulo: 'Progresso',
                    valor: progresso == null
                        ? '—'
                        : '${(progresso * 100).round()}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progresso ?? 0),
            const SizedBox(height: 6),
            Text(
              '${resumo.meus} de ${resumo.meta} · '
              '${resumo.naFila} na fila · ${resumo.aguardando} aguardando',
              style: texto.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: texto.labelMedium),
        Text(valor, style: texto.titleLarge),
      ],
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.filtro,
    required this.onFiltro,
    required this.plataformas,
    required this.plataformaId,
    required this.onPlataforma,
    required this.onBusca,
  });

  final FiltroStatus filtro;
  final ValueChanged<FiltroStatus> onFiltro;
  final List<Plataforma> plataformas;
  final String? plataformaId;
  final ValueChanged<String?> onPlataforma;
  final ValueChanged<String> onBusca;

  @override
  Widget build(BuildContext context) {
    // Se a plataforma escolhida sumiu da lista, volta para "todas".
    final selecionada =
        plataformas.any((p) => p.id == plataformaId) ? plataformaId : null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar título',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onBusca,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: selecionada,
                hint: const Text('Plataforma'),
                onChanged: onPlataforma,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final p in plataformas)
                    DropdownMenuItem(value: p.id, child: Text(p.sigla)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final f in FiltroStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.rotulo),
                    selected: f == filtro,
                    onSelected: (_) => onFiltro(f),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onTap});

  final ItemDetalhado item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final status = item.item.status;
    final valor = item.item.valorCentavos;
    final ano = item.ano;
    return ListTile(
      onTap: onTap,
      leading: Capa(url: item.jogo.capaUrl),
      title: Text(item.jogo.titulo),
      subtitle: Text(
        [
          item.plataforma.nome,
          if (ano != null) '$ano',
          if (valor != null) formatarCentavos(valor),
        ].join(' · '),
      ),
      trailing: Tooltip(
        message: status.rotulo,
        child: Icon(status.icone, color: status.cor(cores)),
      ),
    );
  }
}

class _ListaVazia extends StatelessWidget {
  const _ListaVazia({required this.semItens, this.colecao});

  final bool semItens;
  final String? colecao;

  @override
  Widget build(BuildContext context) {
    final String texto;
    if (!semItens) {
      texto = 'Nenhum item com esses filtros.';
    } else if (colecao != null) {
      texto = '"$colecao" ainda não tem itens.\nUse Adicionar, ou ⋮ → '
          'Adicionar em lote à Wishlist.';
    } else {
      texto = 'Sua coleção está vazia.\nToque em Adicionar para cadastrar '
          'o primeiro jogo.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          texto,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
