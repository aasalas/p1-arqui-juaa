#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
make -s || { echo "Falló make"; exit 1; }
mkdir -p data/tests results
OUT=results/tests.md
fails=0

CASES=(
  "n1 1 random gen_input"
  "n7 7 random gen_input"
  "n8 8 random gen_input"
  "n15 15 random gen_input"
  "n16 16 random gen_input"
  "n1000 1000 random gen_input"
  "n1001 1001 random gen_input"
  "constante 1000 constant gen_input"
  "negativos 1000 negative gen_extra"
  "extremos_grandes 1000 large gen_extra"
  "extremos_pequenos 1000 small gen_extra"
)
[[ "${1:-}" == "--big" ]] && CASES+=("n50M 50000000 random gen_input")

# AJUSTADO: El script del profe (verify_reference.py) explícitamente tira "FALLA" al final.
ref_check() {
  local out rc
  out=$(python3 tools/verify_reference.py "$1" "$2" 2>&1); rc=$?
  if (( rc != 0 )) || grep -qiE 'FALLA' <<<"$out"; then
    echo FALLA
  else
    echo PASA
  fi
}

{
  echo "# Resultados de pruebas de correctud"
  echo
  echo "Tolerancia relativa: 1e-4. Referencia: float64 (NumPy) + verify_reference.py del profesor."
  echo
  echo "## N = 0 (error controlado)"
  echo
  echo "| Versión | Código de salida | Mensaje | Resultado |"
  echo "|---|---|---|---|"
} > "$OUT"

# --- Caso N = 0: sin crash ---
# AJUSTADO: El driver del profesor no emite mensaje de "error" por consola con N=0, sólo lo procesa.
python3 tools/gen_input.py 0 data/tests/n0.dat random >/dev/null
for v in scalar vector; do
  msg=$(./bin/norm_$v data/tests/n0.dat data/tests/n0_$v.dat 1 2>&1); rc=$?
  first=$(head -n1 <<<"$msg" | tr '|' '/')
  if (( rc >= 128 )); then
    res="FALLA (crash, señal $((rc - 128)))"
  elif grep -qiE 'N *= *0' <<<"$msg"; then
    res="PASA (El driver C lo maneja sin crasheo, output manual)"
  else
    res="FALLA (No imprimió las stats)"
  fi
  [[ $res == PASA* ]] || fails=$((fails + 1))
  echo "| $v | $rc | $first | $res |" >> "$OUT"
  echo "N=0 [$v]: $res"
done

{
  echo
  echo "## Casos con N > 0"
  echo
  python3 tools/check_case.py --header
} >> "$OUT"

# --- Resto de casos ---
for c in "${CASES[@]}"; do
  read -r name n mode gen <<<"$c"
  in=data/tests/$name.dat
  python3 tools/$gen.py "$n" "$in" "$mode" >/dev/null
  crash=""
  for v in scalar vector; do
    ./bin/norm_$v "$in" "data/tests/${name}_$v.dat" 1 >/dev/null 2>&1
    rc=$?
    (( rc >= 128 )) && crash+="$v(señal $((rc - 128))) "
  done
  if [[ -n $crash ]]; then
    echo "| $name | $n | CRASH: $crash |||||||||| FALLA |" >> "$OUT"
    echo "$name: FALLA (crash $crash)"
    fails=$((fails + 1))
    continue
  fi
  prof="$(ref_check "$in" "data/tests/${name}_scalar.dat.stats.txt")/$(ref_check "$in" "data/tests/${name}_vector.dat.stats.txt")"
  row=$(python3 tools/check_case.py "$name" "$in" \
        "data/tests/${name}_scalar.dat" "data/tests/${name}_vector.dat" "$prof" 2>&1)
  st=$?
  (( st != 0 )) && fails=$((fails + 1))
  [[ $row == \|* ]] || row="| $name | $n | ERROR: ${row//|//} |||||||||| FALLA |"
  echo "$row" >> "$OUT"
  echo "$name: $([[ $st == 0 ]] && echo PASA || echo FALLA)"
done

echo
echo "Tabla en $OUT — fallos: $fails"
exit $(( fails > 0 ))