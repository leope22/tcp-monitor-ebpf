#!/usr/bin/env bash

# Config de segurança
set -euo pipefail

# Importa lib.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib.sh"

# Recebe os argumentos - ou usa valor padrão
ALGO="${1:-cubic}"
LOSS="${2:-1%}"
DURATION="${3:-30}"

# Define o arquivo de resultados
OUT="results/exp2_loss_${LOSS//%/pct}_${ALGO}.csv"

echo "Experimento 2: Perda aleatória ($LOSS, algoritmo=$ALGO, ${DURATION}s)"
echo "Rode 'iperf3 -s' em outro terminal antes de continuar"
read -rp "Pressione Enter quando o servidor iperf3 estiver pronto"

set_netem loss "$LOSS"

# Inicia o programa eBPF
start_capture "$OUT"

# Inicia iperf3 como cliente apontando para o localhost
iperf3 -c 127.0.0.1 -C "$ALGO" -t "$DURATION"

# Encerra o programa após o iperf3 terminar
stop_capture
clear_netem
echo "Concluído. Dados em $OUT"