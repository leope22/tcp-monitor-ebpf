#!/usr/bin/env bash

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

ALGO="${1:-cubic}"
LOSS="${2:-1%}"
DURATION="${3:-30}"

mkdir -p results
OUT="results/exp2_loss_${LOSS//%/pct}_${ALGO}.csv"

echo "Experimento 2: Perda aleatória ($LOSS, algoritmo=$ALGO, ${DURATION}s)"
echo "Rode 'iperf3 -s' em outro terminal antes de continuar"
read -rp "Pressione Enter quando o servidor iperf3 estiver pronto"

set_netem loss "$LOSS"
start_capture "$OUT"

iperf3 -c 127.0.0.1 -C "$ALGO" -t "$DURATION"

stop_capture
clear_netem
echo "Concluído. Dados em $OUT"