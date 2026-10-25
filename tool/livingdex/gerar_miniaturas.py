"""Gera as miniaturas da LivingDex (120 px, WebP) a partir das imagens HOME
do repositório PokeAPI/sprites.

Uso (na raiz do projeto, com Pillow instalado):
  python tool/livingdex/gerar_miniaturas.py PASTA_SPRITES assets/livingdex/miniaturas

PASTA_SPRITES deve ter as subpastas n/ (regular) e s/ (shiny), com os PNGs
de sprites/pokemon/other/home/{id}.png e .../home/shiny/{id}.png.
"""
import os
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for sub, suf in (('n', ''), ('s', 's')):
    for f in os.listdir(f'{src}/{sub}'):
        im = Image.open(f'{src}/{sub}/{f}').convert('RGBA')
        bb = im.getbbox()
        if bb:  # recorta a margem transparente e centraliza num quadrado
            im = im.crop(bb)
        lado = max(im.size)
        q = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
        q.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2))
        q = q.resize((120, 120), Image.LANCZOS)
        q.save(f'{out}/{f[:-4]}{suf}.webp', 'WEBP', quality=82, method=6)
