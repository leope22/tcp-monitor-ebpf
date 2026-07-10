import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys
import os
import glob

# python3 analyze/plot_tcp_co.py all

def load_and_filter_data(filepath):
    if not os.path.exists(filepath):
        print(f"Arquivo {filepath} não encontrado")
        return None, None
    
    df = pd.read_csv(filepath)
    if df.empty:
        return None, None

    porta_principal = df['src_port'].value_counts().idxmax()
    df_filtrado = df[df['src_port'] == porta_principal].copy()
    df_filtrado['packet_id'] = range(len(df_filtrado))
    
    return df_filtrado, porta_principal

def plot_cwnd(filepath):
    df, porta = load_and_filter_data(filepath)
    if df is None: return

    df.loc[df['ssthresh'] > 1000000000, 'ssthresh'] = np.nan
    zoom_points = 1500
    df_zoom = df.head(zoom_points)

    plt.figure(figsize=(10, 6))
    plt.plot(df_zoom['packet_id'], df_zoom['cwnd'], label='SND_CWND (Janela)', color='blue', linewidth=2)
    plt.plot(df_zoom['packet_id'], df_zoom['ssthresh'], label='SSTHRESH (Limiar)', color='red', linestyle='--', linewidth=2)
    
    plt.title(f'Exp 1: Evolução da Janela de Congestionamento (Porta {porta})')
    plt.xlabel('Eventos TCP Capturados (Cronologia)')
    plt.ylabel('Tamanho (Pacotes)')
    plt.legend()
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.tight_layout()
    
    output_file = filepath.replace('.csv', '_plot.png')
    plt.savefig(output_file, dpi=300)
    print(f"Gráfico Exp 1 salvo: {output_file}")

def plot_rtt(filepaths):
    plt.figure(figsize=(10, 6))
    
    dados_encontrados = False
    for path in filepaths:
        df, porta = load_and_filter_data(path)
        if df is not None:
            dados_encontrados = True
            label = os.path.basename(path).replace('exp3_rtt_', '').replace('.csv', '')
            plt.plot(df['packet_id'], df['srtt'], label=f'SRTT ({label})', alpha=0.8)

    if not dados_encontrados: return

    plt.title('Exp 3: Variação do RTT ao longo do tempo')
    plt.xlabel('Eventos TCP Capturados')
    plt.ylabel('SRTT (Unidades do Kernel)')
    plt.legend()
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.tight_layout()
    
    output_file = "results/exp3_rtt_comparativo_plot.png"
    plt.savefig(output_file, dpi=300)
    print(f"Gráfico Exp 3 salvo: {output_file}")

def plot_retrans(filepath):
    df, porta = load_and_filter_data(filepath)
    if df is None: return
    
    plt.figure(figsize=(10, 6))
    plt.plot(df['packet_id'], df['total_retrans'], label=f'Retransmissões (Porta {porta})', color='orange', linewidth=2)
    
    plt.title('Exp 2: Retransmissões Acumuladas (Cenário com Perda de Pacotes)')
    plt.xlabel('Eventos TCP Capturados')
    plt.ylabel('Total de Retransmissões')
    plt.legend()
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.tight_layout()
    
    output_file = filepath.replace('.csv', '_plot.png')
    plt.savefig(output_file, dpi=300)
    print(f"Gráfico Exp 2 salvo: {output_file}")

def plot_compare(file1, file2, metric='cwnd'):
    df1, porta1 = load_and_filter_data(file1)
    df2, porta2 = load_and_filter_data(file2)
    
    if df1 is None or df2 is None: return

    label1 = os.path.basename(file1).replace('exp4_compare_', '').replace('.csv', '')
    label2 = os.path.basename(file2).replace('exp4_compare_', '').replace('.csv', '')

    plt.figure(figsize=(10, 6))
    plt.plot(df1['packet_id'], df1[metric], label=f'{label1.upper()} (Porta {porta1})', alpha=0.8, linewidth=1.5)
    plt.plot(df2['packet_id'], df2[metric], label=f'{label2.upper()} (Porta {porta2})', alpha=0.8, linewidth=1.5)
    
    plt.title(f'Exp 4: Comparação de Algoritmos (Evolução de {metric.upper()})')
    plt.xlabel('Eventos TCP Capturados')
    plt.ylabel(metric.upper() + ' (Pacotes)')
    plt.legend()
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.tight_layout()
    
    output_file = f"results/exp4_comparacao_{label1}_vs_{label2}_plot.png"
    plt.savefig(output_file, dpi=300)
    print(f"Gráfico Exp 4 salvo: {output_file}")

def gerar_todos_os_graficos():
    
    exp1_files = glob.glob("results/exp1_cwnd_growth_*.csv")
    if exp1_files: plot_cwnd(exp1_files[0])
    
    exp2_files = glob.glob("results/exp2_loss_*.csv")
    if exp2_files: plot_retrans(exp2_files[0])
    
    exp3_files = sorted(glob.glob("results/exp3_rtt_*_cubic.csv"))
    if exp3_files: plot_rtt(exp3_files)
        
    exp4_files = sorted(glob.glob("results/exp4_compare_*.csv"))
    if len(exp4_files) >= 2:
        plot_compare(exp4_files[0], exp4_files[1], metric='cwnd')

    print("\nGráficos salvos na pasta results/.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)

    command = sys.argv[1]
    
    if command == "all":
        gerar_todos_os_graficos()
    elif command == "cwnd" and len(sys.argv) >= 3:
        plot_cwnd(sys.argv[2])
    elif command == "rtt" and len(sys.argv) >= 3:
        plot_rtt(sys.argv[2:])
    elif command == "retrans" and len(sys.argv) >= 3:
        plot_retrans(sys.argv[2])
    elif command == "compare" and len(sys.argv) == 4:
        plot_compare(sys.argv[2], sys.argv[3], metric='cwnd')
    else:
        print("Erro")