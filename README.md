# p1-arqui-juaa — Normalizador estadístico vectorizado (NASM + C)

Proyecto 1 de Arquitectura de Computadores: "Programación Vectorial en
Ensamblador x86-64 (NASM/Linux)". Calcula media, varianza poblacional,
desviación estándar, mínimo y máximo de un arreglo de `float` y lo
normaliza (`out[i] = (in[i] - mean) / stddev`), en dos versiones que
comparten el mismo driver en C:

- **Escalar** (SSE escalar): `asm/scalar/stats_scalar.asm`
- **Vectorial** (AVX2, 8 floats por iteración): `asm/vector/stats_vector.asm`

El enunciado está en [docs/Enunciado_Proyecto_de_curso.pdf](docs/Enunciado_Proyecto_de_curso.pdf)
y el informe en [docs/Proyecto_Arqui.pdf](docs/Proyecto_Arqui.pdf).

## Estructura

```
.
├── Makefile
├── include/
│   └── stats.h                 # Firmas compartidas por ambas versiones
├── src/
│   └── driver.c                # Programa principal (E/S, memoria alineada, timing, resumen)
├── asm/
│   ├── scalar/
│   │   └── stats_scalar.asm    # Versión escalar (SSE escalar)
│   └── vector/
│       └── stats_vector.asm    # Versión vectorial (AVX2)
├── tools/
│   ├── gen_input.py            # Genera entradas: random | constant | edge
│   ├── gen_extra.py            # Genera entradas: negative | large | small (NumPy)
│   ├── verify_reference.py     # Verifica el .stats.txt contra referencia en Python puro
│   ├── check_case.py           # Compara escalar vs vectorial vs referencia float64 (NumPy)
│   └── run_tests.sh            # Corre toda la batería de casos y genera results/tests.md
├── data/
│   └── tests/                  # Entradas y salidas de la batería de pruebas
├── results/
│   └── tests.md                # Tabla de resultados de correctud
└── docs/                       # Enunciado e informe
```

## Implementación

- **`sum_array`**: suma simple (escalar) / acumulación en YMM + reducción
  horizontal y remanente escalar (vectorial).
- **`compute_stats`**: dos pasadas.
  1. Suma con **compensación de Kahan** + `min`/`max`; luego `mean = sum / n`.
  2. Suma de `(x - mean)^2`, también con Kahan; `var = sum_sq / n` (poblacional).

  En la versión vectorial cada pasada procesa bloques de 8 con
  `vmovaps`, reduce con `vextractf128` + `vhaddps` (suma) o
  `vmovshdup`/`vmovhlps` + `vminps`/`vmaxps` (min/max) y termina el
  remanente (`n % 8`) con instrucciones escalares. Si `n <= 0`, escribe
  0.0 en las cuatro salidas.
- **`normalize_array`**: `(x - mean) / stddev` con `vsubps`/`vdivps` en
  bloques de 8 más remanente escalar. Si `stddev == 0.0`, ambas versiones
  **escriben 0.0** en `out[i]` (nota: el comentario de `stats.h` describe
  copiar `in[i]`; la implementación usa ceros).

La versión vectorial usa `vmovaps` (cargas/almacenamientos alineados a
32 bytes); el driver reserva los buffers con `aligned_alloc(32, ...)`.

## Requisitos

- Linux con CPU compatible con AVX2 (verificar con `lscpu | grep avx2`).
- `nasm`, `gcc`, `make`, `python3` y **NumPy** (lo usan `gen_extra.py` y `check_case.py`).
- `gdb` y, opcionalmente, `perf` (paquete `linux-tools`).

## Compilar

```bash
make
```

Genera `bin/norm_scalar` y `bin/norm_vector`: dos ejecutables que
comparten `driver.c` pero enlazan con kernels distintos
(`obj/stats_scalar.o` u `obj/stats_vector.o`). `make clean` borra `obj/` y `bin/`.

## Generar datos

Formato binario (little endian): `int32 n` seguido de `n` valores `float32`.

```bash
python3 tools/gen_input.py 1000000 data/input.dat random [semilla]
python3 tools/gen_input.py 1000    data/input_constant.dat constant
python3 tools/gen_input.py 1000    data/input_edge.dat edge
python3 tools/gen_extra.py 1000    data/input_neg.dat negative   # normal(-1000, 50)
python3 tools/gen_extra.py 1000    data/input_big.dat large      # uniforme [1e14, 1e15]
python3 tools/gen_extra.py 1000    data/input_tiny.dat small     # uniforme [1e-15, 1e-14]
```

## Ejecutar

```bash
./bin/norm_scalar data/input.dat data/output_scalar.dat 30
./bin/norm_vector data/input.dat data/output_vector.dat 30
```

El tercer argumento (opcional, por defecto 1) es el número de repeticiones
del kernel, usado para promediar el tiempo medido con `clock_gettime`.
Atajos: `make run-scalar` y `make run-vector` (10 repeticiones sobre
`data/input.dat`).

Cada corrida escribe también `<output>.stats.txt` con `n`, `sum`, `mean`,
`var`, `stddev`, `min`, `max` y `kernel_ms`.

## Verificar correctud

Un caso individual contra la referencia del profesor:

```bash
python3 tools/verify_reference.py data/input.dat data/output_scalar.dat.stats.txt
python3 tools/verify_reference.py data/input.dat data/output_vector.dat.stats.txt
```

Batería completa (compila, genera los casos en `data/tests/` y escribe
`results/tests.md`):

```bash
bash tools/run_tests.sh          # casos estándar
bash tools/run_tests.sh --big    # agrega N = 50 000 000
```

Casos cubiertos: N = 0, 1, 7, 8, 15, 16, 1000, 1001, constante,
negativos, extremos grandes y extremos pequeños. Para cada uno se
compara media, σ y salida normalizada de ambas versiones contra una
referencia float64 (tolerancia relativa 1e-4) y se corre
`verify_reference.py`. Todos los casos pasan actualmente (ver
[results/tests.md](results/tests.md)).

## Depuración con GDB

Los binarios llevan símbolos de depuración (`-g` en gcc y `-g -F dwarf`
en nasm). La versión vectorial exporta etiquetas globales para poner
breakpoints dentro de los bucles: `vec_stats_loop`, `vec_after_vaddps`,
`vec_tail` y `vec_norm_loop`.

```bash
gdb --args ./bin/norm_vector data/tests/n16.dat data/out.dat 1
(gdb) break vec_after_vaddps
(gdb) run
(gdb) print $ymm6.v8_float
(gdb) stepi
(gdb) break vec_norm_loop
(gdb) x/8fw $rsi
```

(Según la versión de GDB: `info registers ymm0`, `print $ymm0.v8_float`
o `p/x $ymm0`.)
