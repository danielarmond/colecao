"""Gera assets/livingdex/modelos.bin: a "impressão digital" de cada miniatura
(regular e shiny), usada pela carga por print para reconhecer os ícones.

Uso (na raiz do projeto, com Pillow e numpy):
  python tool/livingdex/gerar_modelos.py

Formato: para cada Pokémon do catálogo, na ordem do catalogo.json, dois
blocos de 16 x 16 x 3 bytes (RGB): regular e depois shiny. A normalização é
a mesma de lib/livingdex/leitor_caixa.dart: fundo trocado pela cor da caixa
do HOME, recorte no contorno, quadrado centralizado e média por blocos.
"""
import json

import numpy as np
from PIL import Image

N = 16
FUNDO = np.array([245, 248, 240])


def normalizar(rgb, mascara):
    ys, xs = np.where(mascara)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    c = rgb[y0:y1, x0:x1].astype(float)
    m = mascara[y0:y1, x0:x1]
    c[~m] = FUNDO
    h, w = m.shape
    s = max(h, w)
    q = np.zeros((s, s, 3)) + FUNDO
    q[(s - h) // 2:(s - h) // 2 + h, (s - w) // 2:(s - w) // 2 + w] = c
    out = np.zeros((N, N, 3))
    for i in range(N):
        for j in range(N):
            a, b = i * s // N, max((i + 1) * s // N, i * s // N + 1)
            e, f = j * s // N, max((j + 1) * s // N, j * s // N + 1)
            out[i, j] = q[a:b, e:f].reshape(-1, 3).mean(0)
    return np.clip(np.floor(out + 0.5), 0, 255).astype(np.uint8)


def main():
    cat = json.load(open('assets/livingdex/catalogo.json', encoding='utf-8'))['pokemon']
    blocos = []
    for p in cat:
        for suf in ('', 's'):
            im = np.asarray(Image.open(f"assets/livingdex/miniaturas/{p['id']}{suf}.webp").convert('RGBA'))
            blocos.append(normalizar(im[..., :3], im[..., 3] > 128).tobytes())
    open('assets/livingdex/modelos.bin', 'wb').write(b''.join(blocos))
    print(len(blocos), 'modelos')


if __name__ == '__main__':
    main()
