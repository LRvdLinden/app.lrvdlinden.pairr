#!/usr/bin/env python3
"""Na render.js: exacte maten (productpagina-beelden), RGB zonder alfa, en controle."""
import json, sys
from pathlib import Path
from PIL import Image

root = Path(sys.argv[1]); jobs = json.loads(Path(sys.argv[2]).read_text())
for j in jobs:
    f = root / j["png"]
    im = Image.open(f).convert("RGB")
    if "W" in j and im.size != (j["W"], j["H"]):
        im = im.resize((j["W"], j["H"]), Image.LANCZOS)
    im.save(f, optimize=True)
    print(j["png"], im.size, im.mode)
