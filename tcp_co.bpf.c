#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_core_read.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_endian.h>

#ifndef AF_INET
    #define AF_INET 2
#endif

char LICENSE[] SEC("license") = "GPL";

struct flow_key {
    __u32 src_ip;
    __u32 dst_ip;
    __u16 src_port;
    __u16 dst_port;
};

struct tcp_metrics {
    __u32 snd_cwnd;
    __u32 ssthresh;
    __u32 srtt;
    __u32 retransmissions;
    __u32 duplicate_acks;
    __u64 bytes_acked;
    __u32 packets_out;
    __u32 retrans_out;
    __u32 total_retrans;
    __u32 sndbuf;
    __u8  tcp_state;
    char  ca_name[16]; 
};

struct tcp_event {
    struct flow_key key;
    struct tcp_metrics metrics;
};

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 65536);
    __type(key, struct flow_key);
    __type(value, struct tcp_metrics);
} tcp_flows SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 256 * 1024);
} rb SEC(".maps");

static __always_inline void build_flow_key(struct sock *sk, struct flow_key *key) {
    __builtin_memset(key, 0, sizeof(*key));
    key->src_ip   = BPF_CORE_READ(sk, __sk_common.skc_rcv_saddr);
    key->dst_ip   = BPF_CORE_READ(sk, __sk_common.skc_daddr);
    key->dst_port = bpf_ntohs(BPF_CORE_READ(sk, __sk_common.skc_dport));
    key->src_port = BPF_CORE_READ(sk, __sk_common.skc_num);
}

SEC("fentry/tcp_rcv_established")
int BPF_PROG(trace_tcp_rcv_established, struct sock *sk, struct sk_buff *skb) {
    struct tcp_sock *tp = (struct tcp_sock *)sk;

    if (BPF_CORE_READ(sk, __sk_common.skc_family) != AF_INET)
        return 0;

    struct flow_key key;
    build_flow_key(sk, &key);

    struct tcp_metrics metrics = {};
    
    metrics.snd_cwnd      = BPF_CORE_READ(tp, snd_cwnd);
    metrics.ssthresh      = BPF_CORE_READ(tp, snd_ssthresh);
    metrics.srtt          = BPF_CORE_READ(tp, srtt_us) >> 3;
    metrics.bytes_acked   = BPF_CORE_READ(tp, bytes_acked);
    metrics.packets_out   = BPF_CORE_READ(tp, packets_out);
    metrics.retrans_out   = BPF_CORE_READ(tp, retrans_out);
    metrics.total_retrans = BPF_CORE_READ(tp, total_retrans);
    metrics.sndbuf        = BPF_CORE_READ(sk, sk_sndbuf);
    metrics.tcp_state     = BPF_CORE_READ(sk, __sk_common.skc_state);

    struct inet_connection_sock *icsk = (struct inet_connection_sock *)sk;
    
    metrics.retransmissions = BPF_CORE_READ(icsk, icsk_retransmits);
    metrics.duplicate_acks  = BPF_CORE_READ(tp, sacked_out);

    struct tcp_congestion_ops *ca_ops = NULL;
    bpf_probe_read_kernel(&ca_ops, sizeof(ca_ops), &icsk->icsk_ca_ops);
    
    if (ca_ops) {
        bpf_probe_read_kernel_str(&metrics.ca_name, sizeof(metrics.ca_name), ca_ops->name);
    } else {
        metrics.ca_name[0] = '\0';
    }

    bpf_map_update_elem(&tcp_flows, &key, &metrics, BPF_ANY);

    struct tcp_event *ev = bpf_ringbuf_reserve(&rb, sizeof(*ev), 0);
    if (ev) {
        ev->key = key;
        ev->metrics = metrics;
        bpf_ringbuf_submit(ev, 0);
    }

    return 0;
}