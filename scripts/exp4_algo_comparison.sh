#!/usr/bin/env bash

# Config de segurança
set -euo pipefail

# Importa lib.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

# Recebe os argumentos - ou usa valor padrão
ALGO_A="${1:-reno}"
ALGO_B="${2:-cubic}"
DURATION="${3:-30}"
NETEM_COND="${4:-delay 50ms loss 1%}"

echo "Experimento 4: Comparação $ALGO_A vs $ALGO_B"
echo "Condição de rede aplicada a ambos: $NETEM_COND"
echo "Rode 'iperf3 -s' em outro terminal antes de continuar"
read -rp "Pressione Enter quando o servidor iperf3 estiver pronto"

# Execução de cada algoritmo
for ALGO in "$ALGO_A" "$ALGO_B"; do
    # Define o arquivo de resultados
    OUT="results/exp4_compare_${ALGO}.csv"
    echo ""
    echo "Testando algoritmo=$ALGO"
    set_netem $NETEM_COND

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
echo "Concluído. Arquivos gerados: "
echo "results/exp4_compare_${ALGO_A}.csv"
echo " results/exp4_compare_${ALGO_B}.csv"