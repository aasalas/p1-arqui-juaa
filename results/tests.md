# Resultados de pruebas de correctud

Tolerancia relativa: 1e-4. Referencia: float64 (NumPy) + verify_reference.py del profesor.

## N = 0 (error controlado)

| Versión | Código de salida | Mensaje | Resultado |
|---|---|---|---|
| scalar | 0 | N        = 0 | PASA (El driver C lo maneja sin crasheo, output manual) |
| vector | 0 | N        = 0 | PASA (El driver C lo maneja sin crasheo, output manual) |

## Casos con N > 0

| Caso | N | μ ref | μ esc | μ vec | σ ref | σ esc | σ vec | err máx esc | err máx vec | err esc↔vec | verify_reference (esc/vec) | Resultado |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| n1 | 1 | -36.8029 | -36.8029 | -36.8029 | 0 | 0 | 0 | 6.7e-10 | 6.7e-10 | 0.0e+00 | PASA/PASA | PASA |
| n7 | 7 | 36.2192 | 36.2192 | 36.2192 | 38.9591 | 38.9591 | 38.9591 | 1.0e-07 | 1.0e-07 | 0.0e+00 | PASA/PASA | PASA |
| n8 | 8 | -4.38907 | -4.38907 | -4.38907 | 24.6784 | 24.6784 | 24.6784 | 6.2e-08 | 6.2e-08 | 0.0e+00 | PASA/PASA | PASA |
| n15 | 15 | 4.3121 | 4.3121 | 4.3121 | 57.0635 | 57.0635 | 57.0635 | 1.0e-07 | 1.0e-07 | 0.0e+00 | PASA/PASA | PASA |
| n16 | 16 | -9.16243 | -9.16243 | -9.16243 | 53.6825 | 53.6825 | 53.6825 | 1.2e-07 | 1.2e-07 | 1.0e-07 | PASA/PASA | PASA |
| n1000 | 1000 | 0.673207 | 0.673207 | 0.673207 | 57.9839 | 57.9839 | 57.9839 | 8.0e-07 | 1.2e-07 | 9.1e-07 | PASA/PASA | PASA |
| n1001 | 1001 | 1.68341 | 1.68341 | 1.68341 | 57.2403 | 57.2403 | 57.2403 | 1.0e-07 | 1.0e-07 | 1.4e-07 | PASA/PASA | PASA |
| constante | 1000 | 5 | 5 | 5 | 0 | 0 | 0 | 0.0e+00 | 0.0e+00 | 0.0e+00 | PASA/PASA | PASA |
| negativos | 1000 | -1001.44 | -1001.44 | -1001.44 | 49.4361 | 49.4361 | 49.4361 | 9.2e-07 | 1.3e-07 | 8.8e-07 | PASA/PASA | PASA |
| extremos_grandes | 1000 | 5.4746e+14 | 5.4746e+14 | 5.4746e+14 | 2.62296e+14 | 2.62296e+14 | 2.62296e+14 | 1.6e-07 | 2.6e-07 | 3.1e-07 | PASA/PASA | PASA |
| extremos_pequenos | 1000 | 5.4746e-15 | 5.4746e-15 | 5.4746e-15 | 2.62296e-15 | 2.62296e-15 | 2.62296e-15 | 9.8e-07 | 2.5e-07 | 9.5e-07 | PASA/PASA | PASA |
