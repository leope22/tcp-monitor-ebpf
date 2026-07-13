#!/usr/bin/env bash

# Define variáveis padrão para o programa e a interface de rede 
TCP_CO_BIN="${TCP_CO_BIN:-./tcp_co}"
IFACE="${IFACE:-lo}"

# Iniciar o programa
start_capture() {
    local out_csv="$1"
    
    # Comando de executação - coloca em segundo plano e redireciona os logs para /tmp 
    sudo "$TCP_CO_BIN" "$out_csv" > /tmp/tcp_co_stdout.log 2>&1 &
    
    # Salva o PID do processo
    TCP_CO_PID=$!
    sleep 1
    echo "[lib] tcp_co iniciado (PID=$TCP_CO_PID), gravando em $out_csv"
}

# Encerrar o programa
stop_capture() {
    # Verifica a variável do PID
    if [[ -n "${TCP_CO_PID:-}" ]]; then
        # SIGINT para fechar e limpar a memória
        sudo kill -INT "$TCP_CO_PID" 2>/dev/null || true
        wait "$TCP_CO_PID" 2>/dev/null || true
        
        echo "[lib] tcp_co finalizado"
        unset TCP_CO_PID
    fi
}

# Remover atraso/perda da placa de rede
clear_netem() {
    sudo tc qdisc del dev "$IFACE" root 2>/dev/null || true
}

# Injetar regras na placa de rede
set_netem() {
    clear_netem
    echo "[lib] aplicando netem em $IFACE: $*"
    sudo tc qdisc add dev "$IFACE" root netem "$@"
}

_lib_cleanup() {
    stop_capture
    clear_netem
}

trap _lib_cleanup EXIT