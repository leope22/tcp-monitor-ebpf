#!/usr/bin/env bash

# Config de segurança
set -euo pipefail

# Importa lib.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

# Recebe os argumentos - ou usa valor padrão
ALGO="${1:-cubic}"
DURATION="${2:-20}"
DELAYS=(100ms 200ms 500ms)

echo "Experimento 3: RTT elevado (algoritmo=$ALGO)"
echo "Rode 'iperf3 -s' em outro terminal antes de continuar"
read -rp "Pressione Enter quando o servidor iperf3 estiver pronto"

# Execução de cada delay
for DELAY in "${DELAYS[@]}"; do
    # Define o arquivo de resultados
    OUT="results/exp3_rtt_${DELAY}_${ALGO}.csv"
    echo ""
    echo "Delay=$DELAY"
    set_netem delay "$DELAY"

    # Inicia o programa eBPF
    start_capture "$OUT"

    # Inicia iperf3 como cliente apontando para o localhost
    iperf3 -c 127.0.0.1 -C "$ALGO" -t "$DURATION"

    # Encerra o programa após o iperf3 terminar
    stop_capture
    clear_netem
    sleep 2
done

echo ""
echo "Concluído. Dados em: "
ls -1 results/exp3_rtt_*_"${ALGO}".csv