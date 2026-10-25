"""Gera assets/livingdex/catalogo.json a partir dos CSVs da PokéAPI.

Uso: python tool/livingdex/gerar_catalogo.py PASTA_CSV assets/livingdex/catalogo.json
PASTA_CSV = data/v2/csv do repositório PokeAPI/pokeapi.
"""
import csv, json, sys, datetime
from collections import defaultdict

src, out = sys.argv[1], sys.argv[2]
EN = '9'

def ler(nome):
    with open(f'{src}/{nome}.csv', encoding='utf-8') as f:
        return list(csv.DictReader(f))

pokemon = ler('pokemon')
species_names = {r['pokemon_species_id']: r['name'] for r in ler('pokemon_species_names') if r['local_language_id'] == EN}
forms = ler('pokemon_forms')
form_names = {r['pokemon_form_id']: r for r in ler('pokemon_form_names') if r['local_language_id'] == EN}
types = {r['id']: r['identifier'].capitalize() for r in ler('types')}
ptypes = defaultdict(list)
for r in sorted(ler('pokemon_types'), key=lambda r: int(r['slot'])):
    ptypes[r['pokemon_id']].append(types[r['type_id']])
ability_names = {r['ability_id']: r['name'] for r in ler('ability_names') if r['local_language_id'] == EN}
pab = defaultdict(list)
for r in sorted(ler('pokemon_abilities'), key=lambda r: int(r['slot'])):
    pab[r['pokemon_id']].append((ability_names.get(r['ability_id'], '?'), r['is_hidden'] == '1'))
pstats = defaultdict(dict)
for r in ler('pokemon_stats'):
    pstats[r['pokemon_id']][int(r['stat_id'])] = int(r['base_stat'])
dexes = defaultdict(set)
for r in ler('pokemon_dex_numbers'):
    dexes[r['pokedex_id']].add(int(r['species_id']))

JOGOS_DEX = {'swsh': ['27', '28', '29'], 'pla': ['30'], 'sv': ['31', '32', '33'], 'za': ['34', '35']}
REGIOES_POR_JOGO = {'swsh': {'alola', 'galar'}, 'pla': {'hisui'}, 'sv': {'alola', 'galar', 'hisui', 'paldea'},
                    'za': {'alola', 'galar', 'hisui', 'paldea'}, 'bdsp': set()}
REGIOES = ['alola', 'galar', 'hisui', 'paldea']
EXCLUIR = ('totem', '-cap', '-zen')

# Variantes regionais que a PokéAPI não nomeia como -alola/-galar/-hisui/-paldea:
# identificador -> (região, jogos para onde pode ir).
EXTRAS = {
    'basculin-white-striped': ('hisui', ['pla', 'sv']),
    'ursaluna-bloodmoon': ('paldea', ['sv']),
}

# Shiny indisponível (lista inicial, editável no app).
SHINY_BLOQ = {494, 647, 648, 720, 721, 789, 790, 801, 802, 890, 891, 892, 893, 894, 895, 896, 897, 898,
              905, 1001, 1002, 1003, 1004, 1007, 1008, 1009, 1010, 1014, 1015, 1016, 1017, 1020, 1021,
              1022, 1023, 1024, 1025}

# Formas que mudam o tipo e ficam guardadas no HOME (sem depender de item
# ou de batalha). Entram nas caixas de formas, junto com as regionais.
ALTERNATIVAS = {
    'wormadam-sandy', 'wormadam-trash', 'shaymin-sky',
    'rotom-heat', 'rotom-wash', 'rotom-frost', 'rotom-fan', 'rotom-mow',
    'hoopa-unbound', 'oricorio-pom-pom', 'oricorio-pau', 'oricorio-sensu',
    'necrozma-dusk', 'necrozma-dawn', 'urshifu-rapid-strike',
    'calyrex-ice', 'calyrex-shadow',
}

# Formas com shiny indisponível mesmo quando a espécie tem (por id da PokéAPI).
SHINY_BLOQ_IDS = {10272}  # Bloodmoon Ursaluna


def regiao(ident):
    for r in REGIOES:
        if f'-{r}' in ident:
            return r
    return None

especies_com_hisui = {int(p['species_id']) for p in pokemon if regiao(p['identifier']) == 'hisui'}

def jogos(especie, reg):
    res = []
    for j, ids in JOGOS_DEX.items():
        if not any(especie in dexes[i] for i in ids):
            continue
        if reg is None:
            if j == 'pla' and especie in especies_com_hisui:
                continue
            res.append(j)
        elif reg in REGIOES_POR_JOGO[j]:
            res.append(j)
    if reg is None and especie <= 493:
        res.insert(1 if 'swsh' in res else 0, 'bdsp')
    ordem = ['swsh', 'bdsp', 'pla', 'sv', 'za']
    return sorted(res, key=ordem.index)

form_por_pokemon = {}
for f in forms:
    if f['is_default'] == '1':
        form_por_pokemon[f['pokemon_id']] = f['id']

saida = []
for p in pokemon:
    ident, especie = p['identifier'], int(p['species_id'])
    extra = EXTRAS.get(ident)
    reg = extra[0] if extra else regiao(ident)
    padrao = p['is_default'] == '1'
    alternativa = ident in ALTERNATIVAS
    if not padrao and not extra and not alternativa and (
            reg is None or any(e in ident for e in EXCLUIR)):
        continue
    if padrao and reg is not None:
        continue  # não acontece hoje; garante só formas regionais extras
    nome_especie = species_names[str(especie)]
    nome = nome_especie
    if reg is not None or alternativa:
        fn = form_names.get(form_por_pokemon.get(p['id'], ''), {})
        nome = (fn.get('pokemon_name') or f"{nome_especie} ({reg.capitalize()})").replace('Standard ', '')
    st = pstats[p['id']]
    saida.append({
        'id': int(p['id']),
        'dex': especie,
        'nome': nome,
        'especie': nome_especie,
        'regiao': reg,
        'alternativa': alternativa,
        'tipos': ptypes[p['id']],
        'habilidades': [n for n, h in pab[p['id']] if not h],
        'habilidadeOculta': next((n for n, h in pab[p['id']] if h), None),
        'status': [st.get(i, 0) for i in range(1, 7)],
        'jogos': extra[1] if extra else jogos(especie, reg),
        'shinyBloqueado': especie in SHINY_BLOQ or int(p['id']) in SHINY_BLOQ_IDS,
    })

saida.sort(key=lambda x: (x['regiao'] is not None or x['alternativa'], x['dex'], x['id']))
json.dump({'fonte': 'PokéAPI (github.com/PokeAPI/pokeapi)', 'geradoEm': datetime.date.today().isoformat(),
           'pokemon': saida}, open(out, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
nac = sum(1 for x in saida if x['regiao'] is None and not x['alternativa'])
print(f'{len(saida)} entradas: {nac} nacionais, {len(saida) - nac} formas')
