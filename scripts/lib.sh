#!/usr/bin/env bash

TCP_CO_BIN="${TCP_CO_BIN:-./tcp_co}"
IFACE="${IFACE:-lo}"

start_capture() {
    local out_csv="$1"
    sudo "$TCP_CO_BIN" "$out_csv" > /tmp/tcp_co_stdout.log 2>&1 &
    TCP_CO_PID=$!
    sleep 1
    echo "[lib] tcp_co iniciado (PID=$TCP_CO_PID), gravando em $out_csv"
}

stop_capture() {
    if [[ -n "${TCP_CO_PID:-}" ]]; then
        sudo kill -INT "$TCP_CO_PID" 2>/dev/null || true
        wait "$TCP_CO_PID" 2>/dev/null || true
        echo "[lib] tcp_co finalizado"
        unset TCP_CO_PID
    fi
}

clear_netem() {
    sudo tc qdisc del dev "$IFACE" root 2>/dev/null || true
}

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