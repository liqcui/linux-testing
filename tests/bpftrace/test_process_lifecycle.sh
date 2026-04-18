#!/bin/bash
# test_process_lifecycle.sh - 进程生命周期跟踪测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock_programs"

echo "================================"
echo "bpftrace 进程生命周期测试"
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

# 编译 mock 程序
cd "$MOCK_DIR"
if [[ ! -f process_spawner ]]; then
    echo "编译 process_spawner..."
    make process_spawner
fi

echo "测试场景 1: 进程创建跟踪 (fork)"
echo "==============================="
echo ""

# 启动跟踪
(
echo "开始跟踪进程 fork 事件..."
echo ""
timeout 30 bpftrace -e '
tracepoint:sched:sched_process_fork {
    printf("%s[%d] fork -> child %d\n",
           args->parent_comm, args->parent_pid, args->child_pid);
    @fork_count[args->parent_comm] = count();
}

END {
    printf("\n=== Fork 统计 ===\n");
    print(@fork_count);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 process_spawner (创建 5 个子进程)..."
echo ""
./process_spawner 5 1

wait $TRACE_PID 2>/dev/null

echo ""
echo "测试场景 2: 进程执行跟踪 (exec)"
echo "==============================="
echo ""

(
echo "开始跟踪进程 exec 事件..."
echo ""
timeout 30 bpftrace -e '
tracepoint:sched:sched_process_exec {
    printf("%s[%d] exec: %s\n",
           args->old_comm, args->old_pid, str(args->filename));
    @exec_programs[str(args->filename)] = count();
}

END {
    printf("\n=== Exec 程序统计 ===\n");
    print(@exec_programs);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 process_spawner (创建 6 个子进程，执行不同命令)..."
echo ""
./process_spawner 6 1

wait $TRACE_PID 2>/dev/null

echo ""
echo "测试场景 3: 进程退出跟踪"
echo "======================="
echo ""

(
echo "开始跟踪进程退出事件..."
echo ""
timeout 30 bpftrace -e '
tracepoint:sched:sched_process_exit {
    printf("%s[%d] exit\n", comm, pid);
    @exit_count[comm] = count();
}

END {
    printf("\n=== 退出进程统计 ===\n");
    print(@exit_count);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 process_spawner (创建 5 个短生命周期进程)..."
echo ""
./process_spawner 5 0

wait $TRACE_PID 2>/dev/null

echo ""
echo "测试场景 4: 完整进程生命周期"
echo "==========================="
echo ""

(
echo "跟踪完整生命周期: fork -> exec -> exit (30秒)..."
echo ""
timeout 30 bpftrace -e '
tracepoint:sched:sched_process_fork {
    @start[args->child_pid] = nsecs;
    printf("[FORK] %s[%d] -> child %d\n",
           args->parent_comm, args->parent_pid, args->child_pid);
}

tracepoint:sched:sched_process_exec {
    printf("[EXEC] %s[%d] exec: %s\n",
           args->old_comm, args->old_pid, str(args->filename));
}

tracepoint:sched:sched_process_exit /@start[pid]/ {
    $lifetime_ms = (nsecs - @start[pid]) / 1000000;
    printf("[EXIT] %s[%d] lifetime: %d ms\n",
           comm, pid, $lifetime_ms);
    @lifetime = hist($lifetime_ms);
    delete(@start[pid]);
}

END {
    printf("\n=== 进程生命周期分布 (毫秒) ===\n");
    print(@lifetime);
    clear(@start);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 process_spawner (创建 8 个进程)..."
echo ""
./process_spawner 8 0

wait $TRACE_PID 2>/dev/null

echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果说明:"
echo "  1. Fork 跟踪: 显示父进程创建子进程的事件"
echo "  2. Exec 跟踪: 显示进程执行的具体程序"
echo "  3. Exit 跟踪: 显示进程退出事件"
echo "  4. 生命周期: fork到exit的完整时间分布"
echo ""
echo "process_spawner 会创建子进程并执行:"
echo "  - /bin/echo (每3个进程之一)"
echo "  - /bin/date (每3个进程之一)"
echo "  - /usr/bin/whoami (每3个进程之一)"
echo ""
