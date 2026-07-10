## Guia (WSL)

### Instalar pacotes base

```bash
sudo apt update
sudo apt install -y clang llvm libelf-dev libpcap-dev gcc-multilib build-essential linux-tools-common linux-tools-generic pkg-config git zlib1g-dev
```

### Compilar o `bpftool`

```bash
git clone --recurse-submodules https://github.com/libbpf/bpftool.git
cd bpftool/src
sudo make install
cd ../..
```

### Compilar a `libbpf`

```bash
git clone https://github.com/libbpf/libbpf.git
cd libbpf/src
sudo make install PREFIX=/usr LIBDIR=/usr/lib/x86_64-linux-gnu
cd ../..
sudo ldconfig
```

### Gerar o `vmlinux.h`

```bash
bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
```

### Compilar o código fonte

```bash
# Compila o código C o objeto eBPF
clang -g -O2 -target bpf -D__TARGET_ARCH_x86 -I. -I/usr/include/x86_64-linux-gnu -c tcp_co.bpf.c -o tcp_co.bpf.o

# Gera o Skeleton para conectar o Kernel ao User Space
bpftool gen skeleton tcp_co.bpf.o > tcp_co.skel.h

# Compila o programa em User Space vinculando as bibliotecas
clang -g -O2 -Wall tcp_co.c -lbpf -lelf -lz -o tcp_co
```

### Terminal 1 (Servidor iperf3)

```bash
iperf3 -s
```

### Terminal 2 (Testes)

```bash
# Garantir permissão de execução
chmod +x scripts/*.sh

# Exp 1: Crescimento normal da CWND (30s)
./scripts/exp1_cwnd_growth.sh

# Exp 2: Rede com 1% de perda de pacotes
./scripts/exp2_random_loss.sh

# Exp 3: Rede com alta latência (100ms, 200ms e 500ms)
./scripts/exp3_high_rtt.sh

# Exp 4: Comparação entre CUBIC e BBR (delay 50ms + 1% loss)
./scripts/exp4_algo_comparison.sh cubic bbr
```

### Gerar os gráficos

```bash
python3 analyze/plot_tcp_co.py all
```

### Gerar gráfico CWND do Exp 2

```bash
python3 analyze/plot_tcp_co.py cwnd results/exp2_loss_1pct_cubic.csv
```