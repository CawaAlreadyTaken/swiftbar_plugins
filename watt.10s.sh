#!/usr/bin/env bash
# Stampa i Watt istantanei della batteria (macOS, portatili).
# Segno: positivo = scarica/net draw, negativo = carica.
# Richiede: ioreg, plutil, bc (tutti presenti su macOS).

set -euo pipefail

# Leggi il plist della batteria
plist="$(ioreg -ar -c AppleSmartBattery 2>/dev/null || true)"
if [[ -z "$plist" ]]; then
  echo "N/D"
  exit 1
fi

# Helper per estrarre campi in modo affidabile
get_raw() { plutil -extract "0.$1" raw -o - - <<<"$plist" 2>/dev/null || true; }

amp="$(get_raw InstantAmperage)"
[[ -z "$amp" || "$amp" == "(null)" ]] && amp="$(get_raw Amperage)"
volt="$(get_raw Voltage)"

# Sanifica
amp="$(printf "%s" "$amp" | tr -cd '0-9-')"
volt="$(printf "%s" "$volt" | tr -cd '0-9')"

if [[ -z "$amp" || -z "$volt" ]]; then
  echo "N/D"
  exit 1
fi

# Correzione two's complement (gestisce sia 64-bit sia 32-bit)
d64="$(echo "$amp - 9223372036854775808" | bc)"     # 2^63
if [[ "$d64" != -* ]]; then
  signed_amp="$(echo "$amp - 18446744073709551616" | bc)"  # 2^64
else
  d32="$(echo "$amp - 2147483648" | bc)"           # 2^31
  if [[ "$d32" != -* ]]; then
    signed_amp="$(echo "$amp - 4294967296" | bc)"  # 2^32
  else
    signed_amp="$amp"
  fi
fi

# Watt = -(i[mA] * v[mV]) / 1e6
# (meno per rendere positiva la scarica e negativa la carica)
w="$(echo "scale=6; -1 * ($signed_amp * $volt) / 1000000" | bc)"

# Stampa formattata a 2 decimali
printf "%.2f W\n" "$w"

# Watt screen brightness experiment in idle:
# 1.76 1.77 1.80 1.88 2.00 2.10 2.48 2.72 3.39 3.66 4.04 4.76 4.88 5.53 6.37 7.11 7.54
