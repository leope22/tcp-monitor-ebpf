#!/usr/bin/env bash

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

ALGO="${1:-cubic}"
DURATION="${2:-30}"

mkdir -p results
OUT="results/exp1_cwnd_growth_${ALGO}.csv"

echo "Crescimento da cwnd (algoritmo=$ALGO, ${DURATION}s)"
echo "Rode 'iperf3 -s' em outro terminal antes de continuar"
read -rp "Pressione Enter quando o servidor iperf3 estiver pronto"

clear_netem
start_capture "$OUT"

iperf3 -c 127.0.0.1 -C "$ALGO" -t "$DURATION"

stop_capture
echo "Concluído. Dados em $OUT"