#!/usr/bin/env python3
import re
import struct
import sys
import numpy as np

TOL = 1e-4
DDOF = 0          # Ajustado a la varianza poblacional de verify_reference

# AJUSTADO: Al formato exacto del archivo que exporta el driver (driver.c)
KEYS = {"sum": r"^sum", "mean": r"^mean", "var": r"^var",
        "std": r"^stddev", "min": r"^min", "max": r"^max"}
SKIP = r"(kernel_ms|n=)"

HEADER = ("| Caso | N | μ ref | μ esc | μ vec | σ ref | σ esc | σ vec | "
          "err máx esc | err máx vec | err esc↔vec | verify_reference (esc/vec) | Resultado |\n"
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|")

def load_in(p):
    with open(p, "rb") as f:
        n = struct.unpack("<i", f.read(4))[0]
        return n, np.fromfile(f, dtype="<f4", count=n)

def load_out(p, n):
    raw = np.fromfile(p, dtype="<u1")
    if raw.size == 4 + 4 * n:
        return raw[4:].view("<f4")
    if raw.size == 4 * n:
        return raw.view("<f4")
    raise ValueError(f"{p}: {raw.size} bytes, inesperado para N={n}")

def parse_stats(p):
    d = {}
    for line in open(p, encoding="utf-8", errors="ignore"):
        m = re.match(r"\s*([^:=]+?)\s*[:=]\s*([-+]?(?:\d+\.?\d*(?:[eE][-+]?\d+)?|nan|inf))", line, re.I)
        if not m:
            continue
        key = m.group(1).strip().lower()
        if re.search(SKIP, key):
            continue
        for canon, pat in KEYS.items():
            if canon not in d and re.match(pat, key):
                d[canon] = float(m.group(2))
    missing = set(KEYS) - set(d)
    if missing:
        raise ValueError(f"{p}: faltan claves {missing}; ajustar KEYS al formato del driver")
    return d

def reference(x):
    x64 = x.astype(np.float64)
    m = x64.mean()
    v = ((x64 - m) ** 2).sum() / (x64.size - DDOF)
    s = np.sqrt(v)
    z = np.zeros_like(x64) if s == 0 else (x64 - m) / s
    return {"sum": x64.sum(), "mean": m, "var": v, "std": s,
            "min": x64.min(), "max": x64.max()}, z

def rel_err(a, b, floor):
    return abs(a - b) / max(abs(b), floor)

def main():
    if sys.argv[1] == "--header":
        print(HEADER)
        return 0
    name, fin, fs, fv, prof = sys.argv[1:6]
    n, x = load_in(fin)
    ref, zref = reference(x)
    scale = float(np.abs(x).max())
    floors = {k: (scale ** 2 if k == "var" else scale) * 1e-7 + 1e-38 for k in ref}

    ss, sv = parse_stats(fs + ".stats.txt"), parse_stats(fv + ".stats.txt")
    zs, zv = load_out(fs, n).astype(np.float64), load_out(fv, n).astype(np.float64)

    e_s = max(rel_err(ss[k], ref[k], floors[k]) for k in ref)
    e_v = max(rel_err(sv[k], ref[k], floors[k]) for k in ref)
    ez_s = float(np.max(np.abs(zs - zref) / np.maximum(np.abs(zref), 1.0)))
    ez_v = float(np.max(np.abs(zv - zref) / np.maximum(np.abs(zref), 1.0)))
    e_sv = max(max(rel_err(ss[k], sv[k], floors[k]) for k in ref),
               float(np.max(np.abs(zs - zv) / np.maximum(np.abs(zv), 1.0))))
    finite = all(np.isfinite(list(ss.values()) + list(sv.values()))) \
        and np.isfinite(zs).all() and np.isfinite(zv).all()

    ok = finite and max(e_s, e_v, ez_s, ez_v, e_sv) <= TOL and "FALLA" not in prof
    f = lambda v: f"{v:.6g}"
    print(f"| {name} | {n} | {f(ref['mean'])} | {f(ss['mean'])} | {f(sv['mean'])} | "
          f"{f(ref['std'])} | {f(ss['std'])} | {f(sv['std'])} | "
          f"{max(e_s, ez_s):.1e} | {max(e_v, ez_v):.1e} | {e_sv:.1e} | {prof} | "
          f"{'PASA' if ok else 'FALLA'} |")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())