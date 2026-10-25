import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../livingdex/catalogo.dart';
import '../../providers.dart';
import 'carga_prints_page.dart';
import 'miniatura.dart';
import 'validacao_page.dart';
import 'pokemon_dex_page.dart';

/// LivingDex: todos os Pokémon em ordem de Pokédex (lista) ou nas caixas
/// do HOME (grade 6 × 5, regular à esquerda e shiny à direita).
class LivingDexPage extends ConsumerStatefulWidget {
  const LivingDexPage({super.key});

  @override
  ConsumerState<LivingDexPage> createState() => _LivingDexPageState();
}

class _LivingDexPageState extends ConsumerState<LivingDexPage> {
  FiltroDex _filtro = const FiltroDex();
  bool _caixas = false;
  int _caixaAtual = 0;
  var _paginas = PageController();

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoDexProvider);
    final tenho = ref.watch(dexTenhoProvider).value ?? const <String>{};
    final ajustes = ref.watch(dexAjustesProvider).value ?? const <int, bool>{};
    final pendencias = ref.watch(dexPendenciasProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LivingDex'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Carregar prints do HOME',
            icon: Badge(
              isLabelVisible: pendencias > 0,
              label: Text('$pendencias'),
              child: const Icon(Icons.add_photo_alternate_outlined),
            ),
            onSelected: (op) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => op == 'validar'
                    ? const ValidacaoPage()
                    : const CargaPrintsPage(),
              ),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'carregar',
                child: ListTile(
                  leading: Icon(Icons.add_photo_alternate_outlined),
                  title: Text('Carregar prints'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'validar',
                child: ListTile(
                  leading: const Icon(Icons.pending_actions),
                  title: Text('Aguardando validação ($pendencias)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: _caixas ? 'Ver em lista' : 'Ver em caixas',
            icon: Icon(_caixas ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() {
              if (!_caixas) {
                // A grade volta na caixa em que você estava.
                final antigo = _paginas;
                _paginas = PageController(initialPage: _caixaAtual);
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => antigo.dispose());
              }
              _caixas = !_caixas;
            }),
          ),
        ],
      ),
      body: catalogo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao abrir o catálogo: $e')),
        data: (cat) {
          final regular =
              progressoDex(cat, shiny: false, tenho: tenho, ajustes: ajustes);
          final shiny =
              progressoDex(cat, shiny: true, tenho: tenho, ajustes: ajustes);
          return Column(
            children: [
              _Progresso(regular: regular, shiny: shiny),
              Expanded(
                child: _caixas
                    ? _VisaoCaixas(
                        catalogo: cat,
                        tenho: tenho,
                        ajustes: ajustes,
                        controle: _paginas,
                        atual: _caixaAtual,
                        onPagina: (i) => setState(() => _caixaAtual = i),
                        onAbrir: _abrir,
                      )
                    : _VisaoLista(
                        catalogo: cat,
                        filtro: _filtro,
                        tenho: tenho,
                        ajustes: ajustes,
                        onFiltro: (f) => setState(() => _filtro = f),
                        onAbrir: _abrir,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrir(PokemonDex p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PokemonDexPage(pokemon: p)),
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso({required this.regular, required this.shiny});

  final ({int tenho, int total}) regular;
  final ({int tenho, int total}) shiny;

  @override
  Widget build(BuildContext context) {
    Widget barra(String rotulo, ({int tenho, int total}) p, IconData icone) {
      final texto = Theme.of(context).textTheme;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 16),
                const SizedBox(width: 4),
                Text(rotulo, style: texto.labelLarge),
                const Spacer(),
                Text('${p.tenho} de ${p.total}', style: texto.labelLarge),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: p.total == 0 ? 0 : p.tenho / p.total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          barra('Regular', regular, Icons.catching_pokemon),
          const SizedBox(width: 20),
          barra('Shiny', shiny, Icons.auto_awesome),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- lista

class _VisaoLista extends ConsumerWidget {
  const _VisaoLista({
    required this.catalogo,
    required this.filtro,
    required this.tenho,
    required this.ajustes,
    required this.onFiltro,
    required this.onAbrir,
  });

  final CatalogoDex catalogo;
  final FiltroDex filtro;
  final Set<String> tenho;
  final Map<int, bool> ajustes;
  final ValueChanged<FiltroDex> onFiltro;
  final ValueChanged<PokemonDex> onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista =
        filtrarDex(catalogo, filtro, tenho: tenho, ajustes: ajustes);
    final shiny = filtro.shiny;
    final cores = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Regular')),
                  ButtonSegment(value: true, label: Text('Shiny')),
                ],
                selected: {shiny},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    onFiltro(filtro.copiar(shiny: s.first)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Nome ou número',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (t) => onFiltro(filtro.copiar(busca: t)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final (posse, rotulo) in const [
                (PosseDex.todos, 'Todos'),
                (PosseDex.tenho, 'Tenho'),
                (PosseDex.falta, 'Falta'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(rotulo),
                    selected: filtro.posse == posse,
                    onSelected: (_) => onFiltro(filtro.copiar(posse: posse)),
                  ),
                ),
              const SizedBox(width: 6),
              _Escolha<String>(
                rotulo: 'Tipo',
                valor: filtro.tipo,
                opcoes: [for (final t in catalogo.tipos) (t, t)],
                onChanged: (t) => onFiltro(filtro.copiar(tipo: () => t)),
              ),
              const SizedBox(width: 6),
              _Escolha<JogoDex>(
                rotulo: 'Pode ir para',
                valor: filtro.jogo,
                opcoes: [for (final j in JogoDex.values) (j, j.rotulo)],
                onChanged: (j) => onFiltro(filtro.copiar(jogo: () => j)),
              ),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Nenhum Pokémon neste filtro.'))
              : ListView.builder(
                  itemCount: lista.length,
                  itemExtent: 68,
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    final bloqueado = shiny && shinyBloqueado(p, ajustes);
                    final meu = tenho.contains(chaveDex(p.id, shiny: shiny));
                    return ListTile(
                      onTap: () => onAbrir(p),
                      leading: MiniaturaDex(
                        pokemon: p,
                        shiny: shiny,
                        tenho: meu,
                      ),
                      title: Text(
                        p.nome,
                        style: bloqueado
                            ? TextStyle(color: cores.outline)
                            : null,
                      ),
                      subtitle: Text(
                        bloqueado
                            ? '${p.numero} · Shiny não disponível'
                            : '${p.numero} · ${p.tipos.join(' / ')}',
                      ),
                      trailing: bloqueado
                          ? Icon(Icons.block, color: cores.outline)
                          : IconButton(
                              tooltip: meu ? 'Tenho' : 'Falta',
                              icon: Icon(
                                meu
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: meu ? cores.primary : cores.outline,
                              ),
                              onPressed: () => ref
                                  .read(repositorioDexProvider)
                                  .definirTenho(p.id, shiny: shiny, tenho: !meu),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Chip que abre uma lista de opções (com "Todos" para limpar).
class _Escolha<T> extends StatelessWidget {
  const _Escolha({
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
  });

  final String rotulo;
  final T? valor;
  final List<(T, String)> opcoes;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    String? atual;
    for (final (v, r) in opcoes) {
      if (v == valor) atual = r;
    }
    return InputChip(
      label: Text(atual == null ? rotulo : '$rotulo: $atual'),
      selected: valor != null,
      showCheckmark: false,
      avatar: const Icon(Icons.arrow_drop_down),
      onDeleted: valor == null ? null : () => onChanged(null),
      onPressed: () async {
        final escolhido = await showModalBottomSheet<(T?,)>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Todos'),
                  onTap: () => Navigator.pop(ctx, (null,)),
                ),
                for (final (v, r) in opcoes)
                  ListTile(
                    title: Text(r),
                    selected: v == valor,
                    onTap: () => Navigator.pop(ctx, (v,)),
                  ),
              ],
            ),
          ),
        );
        if (escolhido != null) onChanged(escolhido.$1);
      },
    );
  }
}

// ---------------------------------------------------------------- caixas

class _VisaoCaixas extends ConsumerWidget {
  const _VisaoCaixas({
    required this.catalogo,
    required this.tenho,
    required this.ajustes,
    required this.controle,
    required this.atual,
    required this.onPagina,
    required this.onAbrir,
  });

  final CatalogoDex catalogo;
  final Set<String> tenho;
  final Map<int, bool> ajustes;
  final PageController controle;
  final int atual;
  final ValueChanged<int> onPagina;
  final ValueChanged<PokemonDex> onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caixas = catalogo.caixas;
    final texto = Theme.of(context).textTheme;

    void irPara(int i) {
      if (i < 0 || i >= caixas.length) return;
      if (controle.hasClients) controle.jumpToPage(i);
      onPagina(i);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: atual > 0 ? () => irPara(atual - 1) : null,
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final i = await showModalBottomSheet<int>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => ListView.builder(
                        itemCount: caixas.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(caixas[i].nome),
                          trailing: Text('${i + 1}'),
                          selected: i == atual,
                          onTap: () => Navigator.pop(ctx, i),
                        ),
                      ),
                    );
                    if (i != null) irPara(i);
                  },
                  child: Text(
                    '${caixas[atual].nome}  ·  ${atual + 1}/${caixas.length}',
                    style: texto.titleMedium,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    atual < caixas.length - 1 ? () => irPara(atual + 1) : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: controle,
            itemCount: caixas.length,
            onPageChanged: onPagina,
            itemBuilder: (context, c) => _Caixa(
              caixa: caixas[c],
              tenho: tenho,
              ajustes: ajustes,
              onAbrir: onAbrir,
            ),
          ),
        ),
      ],
    );
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({
    required this.caixa,
    required this.tenho,
    required this.ajustes,
    required this.onAbrir,
  });

  final CaixaDex caixa;
  final Set<String> tenho;
  final Map<int, bool> ajustes;
  final ValueChanged<PokemonDex> onAbrir;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 30,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemBuilder: (context, k) {
          final i = k ~/ 2;
          final shiny = k.isOdd;
          final fundo = BoxDecoration(
            color: shiny
                ? cores.tertiaryContainer.withValues(alpha: 0.35)
                : cores.surfaceContainerHighest,
            shape: BoxShape.circle,
          );
          if (i >= caixa.pokemon.length) {
            return DecoratedBox(decoration: fundo);
          }
          final p = caixa.pokemon[i];
          final bloqueado = shiny && shinyBloqueado(p, ajustes);
          return Tooltip(
            message: '${p.nome}${shiny ? ' (shiny)' : ''}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onAbrir(p),
              child: DecoratedBox(
                decoration: fundo,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: bloqueado
                      ? Icon(Icons.block, size: 18, color: cores.outlineVariant)
                      : MiniaturaDex(
                          pokemon: p,
                          shiny: shiny,
                          tenho: tenho.contains(chaveDex(p.id, shiny: shiny)),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
