#!/bin/bash
# test_tcp_lifecycle.sh - TCP 连接生命周期跟踪测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BCC_MOCK_DIR="$SCRIPT_DIR/../bcc/mock_programs"

echo "================================"
echo "bpftrace TCP 生命周期测试"
echo "================================"
echo ""

# 检查 bpftrace
if ! command -v bpftrace &> /dev/null; then
    echo "错误: bpftrace 未安装"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限运行"
   echo "使用: sudo $0"
   exit 1
fi

# 检查并编译 BCC mock 程序
if [[ -d "$BCC_MOCK_DIR" ]]; then
    cd "$BCC_MOCK_DIR"
    if [[ ! -f tcp_client ]]; then
        echo "编译 tcp_client..."
        make tcp_client 2>/dev/null
    fi
else
    echo "警告: BCC mock 程序目录不存在"
    echo "将使用 curl 进行测试"
fi

echo "测试场景 1: TCP 状态转换跟踪"
echo "============================="
echo ""
echo "TCP 状态说明:"
echo "  1=ESTABLISHED  2=SYN_SENT   3=SYN_RECV"
echo "  4=FIN_WAIT1    5=FIN_WAIT2  6=TIME_WAIT"
echo "  7=CLOSE        8=CLOSE_WAIT 9=LAST_ACK"
echo "  10=LISTEN      11=CLOSING"
echo ""

# 启动 bpftrace 跟踪
(
echo "开始跟踪 TCP 状态变化 (30秒)..."
echo ""
timeout 30 bpftrace -e '
tracepoint:sock:inet_sock_set_state {
    printf("%s [%d] %s:%d -> %s:%d state: %d -> %d (protocol: %d)\\n",
        comm, pid,
        ntop(args->saddr), args->sport,
        ntop(args->daddr), args->dport,
        args->oldstate, args->newstate,
        args->protocol);
    @state_changes++;
}

END {
    printf("\\n总状态变化: %d 次\\n", @state_changes);
}
'
) &
TRACE_PID=$!

sleep 3

echo "发起 TCP 连接测试..."
echo ""

# 使用 tcp_client 或 curl
if [[ -f "$BCC_MOCK_DIR/tcp_client" ]]; then
    echo "使用 tcp_client 连接 Google, GitHub..."
    "$BCC_MOCK_DIR/tcp_client" 5 1 2>/dev/null &
    CLIENT_PID=$!
    sleep 8
else
    echo "使用 curl 测试..."
    for i in {1..3}; do
        echo "  连接 $i: www.google.com"
        curl -s --max-time 3 https://www.google.com > /dev/null 2>&1 &
        sleep 2
        echo "  连接 $i: github.com"
        curl -s --max-time 3 https://github.com > /dev/null 2>&1 &
        sleep 2
    done
fi

wait $TRACE_PID 2>/dev/null
[[ -n "$CLIENT_PID" ]] && wait $CLIENT_PID 2>/dev/null

echo ""
echo "测试场景 2: TCP 连接建立统计"
echo "============================="
echo ""

(
echo "跟踪新建 TCP 连接 (30秒)..."
echo ""
timeout 30 bpftrace -e '
tracepoint:sock:inet_sock_set_state {
    if (args->newstate == 1 && args->protocol == 6) {  // ESTABLISHED and TCP
        printf("%s [%d] NEW CONNECTION: %s:%d -> %s:%d\\n",
            comm, pid,
            ntop(args->saddr), args->sport,
            ntop(args->daddr), args->dport);

        @connections[comm] = count();
    }
}

END {
    printf("\\n=== TCP 连接统计 ===\\n");
    print(@connections);
}
'
) &
TRACE_PID=$!

sleep 3

echo "发起多个连接..."
echo ""

for i in {1..5}; do
    curl -s --max-time 3 https://www.baidu.com > /dev/null 2>&1 &
    sleep 1
done

wait $TRACE_PID 2>/dev/null

echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果说明:"
echo "  - 第一个测试显示详细的 TCP 状态转换"
echo "  - 第二个测试统计每个进程建立的连接数"
echo "  - 典型流程: 7(CLOSE) -> 2(SYN_SENT) -> 1(ESTABLISHED) -> 4(FIN_WAIT1) -> 6(TIME_WAIT)"
echo ""
echo "常见状态转换:"
echo "  客户端: CLOSE -> SYN_SENT -> ESTABLISHED -> FIN_WAIT1 -> FIN_WAIT2 -> TIME_WAIT"
echo "  服务端: CLOSE -> LISTEN -> SYN_RECV -> ESTABLISHED -> CLOSE_WAIT -> LAST_ACK"
echo ""
