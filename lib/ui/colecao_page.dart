import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/banco.dart';
import '../data/repositorio.dart';
import '../domain/notas.dart';
import '../domain/regras.dart';
import '../domain/tipos.dart';
import '../providers.dart';
import 'backup_page.dart';
import 'estatisticas_page.dart';
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
    final capaTodos = ref.watch(capaTodosProvider).value;

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
          title: const Text('Mídia Física'),
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
                _ResumoCard(
                  resumo: resumo,
                  capaUrl: aberta == null ? capaTodos : aberta.capaUrl,
                ),
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
        ],
        const PopupMenuItem(
          value: 'capa',
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Escolher capa'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if ((aberta == null
                ? ref.read(capaTodosProvider).value
                : aberta.capaUrl) !=
            null)
          const PopupMenuItem(
            value: 'semCapa',
            child: ListTile(
              leading: Icon(Icons.hide_image_outlined),
              title: Text('Remover capa'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'estatisticas',
          child: ListTile(
            leading: Icon(Icons.insights_outlined),
            title: Text('Estatísticas'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'notas',
          child: ListTile(
            leading: Icon(Icons.star_half),
            title: Text('Atualizar notas da comunidade'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
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
            dica: 'Nova coleção',
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
      case 'notas':
        await _atualizarNotas(context);
      case 'estatisticas':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EstatisticasPage(colecao: aberta),
          ),
        );
      case 'capa':
        {
          final itens = ref.read(itensProvider).value ?? const [];
          final vinculos = ref.read(vinculosProvider).value ?? const {};
          final daAba = aberta == null
              ? itens
              : [
                  for (final i in itens)
                    if (vinculos[i.item.id]?.contains(aberta.id) ?? false) i,
                ];
          final url = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => _EscolherCapaPage(
                nome: aberta?.nome ?? 'Todos',
                itens: daAba,
                capaAtual: aberta == null
                    ? ref.read(capaTodosProvider).value
                    : aberta.capaUrl,
              ),
            ),
          );
          if (url == null) return;
          if (aberta == null) {
            await repo.definirCapaTodos(url);
          } else {
            await repo.definirCapaColecao(aberta.id, url);
          }
        }
      case 'semCapa':
        if (aberta == null) {
          await repo.definirCapaTodos(null);
        } else {
          await repo.definirCapaColecao(aberta.id, null);
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

  /// Busca na RAWG a nota da comunidade de todos os jogos vinculados,
  /// mostrando o andamento.
  Future<void> _atualizarNotas(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Atualizar notas da comunidade',
      mensagem: 'O app consulta a RAWG uma vez para cada jogo vinculado. '
          'Pode levar alguns minutos.',
      botao: 'Atualizar',
    );
    if (!ok || !context.mounted) return;

    final andamento = ValueNotifier<String>('Preparando…');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: andamento,
                builder: (_, texto, _) => Text(texto),
              ),
            ),
          ],
        ),
      ),
    );
    ResultadoNotas? r;
    String? falha;
    try {
      r = await ref.read(repositorioProvider).atualizarNotasComunidade(
            ref.read(rawgProvider),
            progresso: (feitos, total) =>
                andamento.value = 'Atualizando $feitos de $total…',
          );
    } catch (e) {
      falha = '$e';
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
    andamento.dispose();
    if (!context.mounted) return;

    final String mensagem;
    if (r == null) {
      mensagem = 'Não foi possível atualizar: $falha';
    } else if (r.total == 0) {
      mensagem = 'Nenhum jogo está vinculado à RAWG. Vincule pela tela do '
          'item (botão "Vincular à RAWG").';
    } else {
      mensagem = [
        '${r.atualizados} de ${r.total} jogos consultados; '
            '${r.comNota} têm nota na RAWG.',
        if (r.erro != null) 'Último erro: ${r.erro}',
      ].join('\n');
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notas da comunidade'),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _noRecorte(ItemDetalhado i) {
    if (_plataformaId != null && i.plataforma.id != _plataformaId) {
      return false;
    }
    if (_busca.isNotEmpty) {
      final q = normalizarTitulo(_busca);
      if (!normalizarTitulo(i.titulo).contains(q) &&
          !i.jogo.tituloBusca.contains(q)) {
        return false;
      }
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
  const _ResumoCard({required this.resumo, this.capaUrl});

  final ResumoColecao resumo;

  /// Capa da coleção: vira o fundo do cartão, cortada para caber.
  final String? capaUrl;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final progresso = resumo.progresso;
    final capa = capaUrl;
    final cor = capa == null ? null : Colors.white;

    final conteudo = Padding(
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
                  cor: cor,
                ),
              ),
              Expanded(
                child: _Numero(
                  rotulo: 'Progresso',
                  valor: progresso == null
                      ? '—'
                      : '${(progresso * 100).round()}%',
                  cor: cor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progresso ?? 0,
            color: cor,
            backgroundColor: capa == null ? null : Colors.white24,
          ),
          const SizedBox(height: 6),
          Text(
            '${resumo.meus} de ${resumo.meta} · '
            '${resumo.naFila} na fila · ${resumo.aguardando} aguardando',
            style: texto.bodySmall?.copyWith(color: cor),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: capa == null
          ? conteudo
          : Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: capa,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                // Escurece a imagem para os números ficarem legíveis.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xCC000000), Color(0x66000000)],
                      ),
                    ),
                  ),
                ),
                conteudo,
              ],
            ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.rotulo, required this.valor, this.cor});

  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: texto.labelMedium?.copyWith(color: cor)),
        Text(valor, style: texto.titleLarge?.copyWith(color: cor)),
      ],
    );
  }
}

/// Grade com as capas dos itens da coleção; devolve a URL escolhida.
class _EscolherCapaPage extends StatelessWidget {
  const _EscolherCapaPage({
    required this.nome,
    required this.itens,
    this.capaAtual,
  });

  final String nome;
  final List<ItemDetalhado> itens;
  final String? capaAtual;

  @override
  Widget build(BuildContext context) {
    // Uma opção por capa (itens duplicados compartilham a mesma imagem).
    final porCapa = <String, ItemDetalhado>{};
    for (final i in itens) {
      final u = i.capaUrl;
      if (u != null) porCapa.putIfAbsent(u, () => i);
    }
    final opcoes = porCapa.entries.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Capa · $nome')),
      body: opcoes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum item desta coleção tem capa. Vincule os jogos à '
                  'RAWG na tela do item.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: opcoes.length,
              itemBuilder: (context, i) {
                final o = opcoes[i];
                final atual = o.key == capaAtual;
                return InkWell(
                  onTap: () => Navigator.pop(context, o.key),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: atual
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 3,
                                  )
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: o.key,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        o.value.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
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
  const _ItemTile({
    required this.item,
    required this.onTap,
  });

  final ItemDetalhado item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final status = item.item.status;
    final ano = item.ano;
    final comunidade =
        formatarNotaComunidade(item.jogo.notaComunidade, null);
    return ListTile(
      onTap: onTap,
      leading: Capa(url: item.capaUrl),
      title: TituloComMedalha(titulo: item.titulo, zerado: item.item.zerado),
      subtitle: Text(
        [
          item.plataforma.nome,
          if (ano != null) '$ano',
          if (comunidade != null) comunidade,
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
