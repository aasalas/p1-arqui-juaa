#!/usr/bin/env python3
"""Genera entradas extra (negativos / extremos) con el mismo formato que gen_input.py:
int32 N little-endian + N float32. Uso: gen_extra.py N ruta negative|large|small"""
import sys
import numpy as np

n, path, mode = int(sys.argv[1]), sys.argv[2], sys.argv[3]
rng = np.random.default_rng(42)
if mode == "negative":
    x = rng.normal(-1000.0, 50.0, n)
elif mode == "large":            # d^2 ~ 1e29, suma < 3.4e38 (máximo de float32)
    x = rng.uniform(1e14, 1e15, n)
elif mode == "small":            # d^2 ~ 1e-30, sigue por encima del mínimo normal de float32
    x = rng.uniform(1e-15, 1e-14, n)
else:
    sys.exit(f"modo desconocido: {mode}")
with open(path, "wb") as f:
    np.array([n], dtype="<i4").tofile(f)
    x.astype("<f4").tofile(f)