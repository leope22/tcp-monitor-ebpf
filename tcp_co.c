#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>
#include <time.h> 
#include "tcp_co.skel.h"

struct flow_key { uint32_t src_ip; uint32_t dst_ip; uint16_t src_port; uint16_t dst_port; };
struct tcp_metrics { uint32_t snd_cwnd; uint32_t ssthresh; uint32_t srtt; uint32_t retransmissions; uint32_t duplicate_acks; uint64_t bytes_acked; uint32_t packets_out; uint32_t retrans_out; uint32_t total_retrans; uint32_t sndbuf; uint8_t tcp_state; char ca_name[16]; };
struct tcp_event { struct flow_key key; struct tcp_metrics metrics; };

FILE *csv_file = NULL; 

static int handle_event(void *ctx, void *data, size_t data_sz) {
    const struct tcp_event *e = data;
    char src_ip[INET_ADDRSTRLEN], dst_ip[INET_ADDRSTRLEN];
    time_t now = time(NULL); 

    inet_ntop(AF_INET, &e->key.src_ip, src_ip, sizeof(src_ip));
    inet_ntop(AF_INET, &e->key.dst_ip, dst_ip, sizeof(dst_ip));

    if (csv_file) {
        fprintf(csv_file, "%ld,%s,%u,%s,%u,%u,%u,%u,%llu,%u,%u,%s,%u,%u,%u,%u,%u\n",
                now, src_ip, ntohs(e->key.src_port), dst_ip, ntohs(e->key.dst_port),
                e->metrics.snd_cwnd, e->metrics.ssthresh, e->metrics.srtt,
                (unsigned long long)e->metrics.bytes_acked, e->metrics.tcp_state, 
                e->metrics.packets_out, e->metrics.ca_name,
                e->metrics.retrans_out, e->metrics.total_retrans, e->metrics.sndbuf,
                e->metrics.retransmissions, e->metrics.duplicate_acks);
    }
    return 0;
}

static volatile bool exiting = false;

static void sig_handler(int sig) {
    exiting = true;
}

int main(int argc, char **argv) {
    struct tcp_co_bpf *skel;
    struct ring_buffer *rb = NULL;
    
    const char *filename = (argc > 1) ? argv[1] : "tcp_co_output.csv";
    csv_file = fopen(filename, "w");
    if (csv_file) {
        fprintf(csv_file, "timestamp,src_ip,src_port,dst_ip,dst_port,cwnd,ssthresh,srtt,bytes_acked,state,packets_out,ca_name,retrans_out,total_retrans,sndbuf,retransmissions,duplicate_acks\n");
    }

    skel = tcp_co_bpf__open_and_load();
    if (!skel) return 1;

    tcp_co_bpf__attach(skel);
    rb = ring_buffer__new(bpf_map__fd(skel->maps.rb), handle_event, NULL, NULL);

    printf("Gravando dados em %s\n", filename);

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    while (!exiting) {
        if (ring_buffer__poll(rb, 100) < 0) break;
    }

    int map_fd = bpf_map__fd(skel->maps.tcp_flows);
    struct flow_key key = {}, next_key;
    struct tcp_metrics metrics;

    while (bpf_map_get_next_key(map_fd, &key, &next_key) == 0) {
        bpf_map_lookup_elem(map_fd, &next_key, &metrics);
        char src[INET_ADDRSTRLEN], dst[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &next_key.src_ip, src, sizeof(src));
        inet_ntop(AF_INET, &next_key.dst_ip, dst, sizeof(dst));
        
        if (metrics.snd_cwnd > 0) {
            printf("\nFluxo: %s:%d -> %s:%d - Algoritmo: %s\n"
                   "CWND: %u\n"
                   "SSTHRESH: %u\n"
                   "SRTT: %u us\n"
                   "Bytes Acked: %llu bytes\n"
                   "Packets Out: %u\n"
                   "Retrans Out: %u\n"
                   "Total Retrans: %u\n"
                   "SNDBUF: %u bytes\n"
                   "Retransmissions: %u\n"
                   "Duplicate ACKs: %u\n",
                   src, ntohs(next_key.src_port), dst, ntohs(next_key.dst_port),
                   metrics.ca_name[0] != '\0' ? metrics.ca_name : "N/A",
                   metrics.snd_cwnd, 
                   metrics.ssthresh, 
                   metrics.srtt,
                   (unsigned long long)metrics.bytes_acked, 
                   metrics.packets_out, 
                   metrics.retrans_out, 
                   metrics.total_retrans, 
                   metrics.sndbuf,
                   metrics.retransmissions, 
                   metrics.duplicate_acks);
        }
        key = next_key;
    }

    if (csv_file) fclose(csv_file); 
    ring_buffer__free(rb);
    tcp_co_bpf__destroy(skel);
    return 0;
}