"""Extrai da planilha "Austin John's HOME Living Dex Organizer" (aba Dex) em
que jogos do Switch cada Pokémon/forma aparece na Pokédex, com o número
regional (ex.: SV "K194" = Kitakami 194; SwSh "A068" = Isle of Armor 68,
"C" = Crown Tundra; SV "P" = Paldea, "B" = Blueberry).

Uso: python tool/livingdex/extrair_jogos_switch.py PLANILHA.xlsx tool/livingdex/jogos_switch.csv
Só as linhas sem diferença de gênero entram.
"""
import csv
import sys

import openpyxl

origem, destino = sys.argv[1], sys.argv[2]
wb = openpyxl.load_workbook(origem, data_only=True)
linhas = []
for r in wb['Dex'].iter_rows(min_row=2, values_only=True):
    especie, forma, idx_forma, genero, nat = r[0], r[1], r[2], r[3], r[6]
    if not especie or not nat or genero:
        continue

    def v(x):
        if x is None or x == '':
            return ''
        return str(int(x)) if isinstance(x, float) else str(x).strip()

    linhas.append([int(nat), especie, '' if forma is None else str(forma).strip(),
                   '' if idx_forma is None else int(idx_forma),
                   *[v(x) for x in r[7:12]]])
with open(destino, 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['dex', 'especie', 'forma', 'indice_forma', 'swsh', 'bdsp', 'pla', 'sv', 'lza'])
    w.writerows(linhas)
print(len(linhas), 'linhas')
