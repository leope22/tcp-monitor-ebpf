#!/usr/bin/env bash

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

ALGO="${1:-cubic}"
DURATION="${2:-20}"
DELAYS=(100ms 200ms 500ms)

mkdir -p results

echo "Experimento 3: RTT elevado (algoritmo=$ALGO)"
echo "Rode 'iperf3 -s' em outro terminal antes de continuar"
read -rp "Pressione Enter quando o servidor iperf3 estiver pronto"

for DELAY in "${DELAYS[@]}"; do
    OUT="results/exp3_rtt_${DELAY}_${ALGO}.csv"
    echo ""
    echo "Delay=$DELAY"
    set_netem delay "$DELAY"
    start_capture "$OUT"

    iperf3 -c 127.0.0.1 -C "$ALGO" -t "$DURATION"

    stop_capture
    clear_netem
    sleep 2
done

echo ""
echo "Concluído. Dados em: "
ls -1 results/exp3_rtt_*_"${ALGO}".csv