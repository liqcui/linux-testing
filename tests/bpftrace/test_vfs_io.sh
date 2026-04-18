#!/bin/bash
# test_vfs_io.sh - VFS I/O 操作跟踪测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock_programs"

echo "================================"
echo "bpftrace VFS I/O 跟踪测试"
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
if [[ ! -f io_generator ]]; then
    echo "编译 io_generator..."
    make io_generator
fi

echo "测试场景 1: VFS 读写操作统计"
echo "============================"
echo ""

# 启动跟踪
(
echo "开始跟踪 VFS 读写操作 (30秒)..."
echo ""
timeout 30 bpftrace -e '
kprobe:vfs_read {
    @vfs_ops["vfs_read"] = count();
    @vfs_bytes["read"] = sum(arg2);
}

kprobe:vfs_write {
    @vfs_ops["vfs_write"] = count();
    @vfs_bytes["write"] = sum(arg2);
}

END {
    printf("\n=== VFS 操作统计 ===\n");
    print(@vfs_ops);
    printf("\n=== VFS 字节数统计 ===\n");
    print(@vfs_bytes);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 io_generator (写操作，20次，每次4KB)..."
echo ""
./io_generator write 20 4096

wait $TRACE_PID 2>/dev/null

echo ""
echo "测试场景 2: 按进程跟踪 I/O"
echo "========================="
echo ""

# 先启动程序获取 PID
./io_generator write 30 8192 > /tmp/io_gen.log 2>&1 &
IO_PID=$!
echo "io_generator PID: $IO_PID"

sleep 2

echo ""
echo "跟踪特定进程的 I/O 操作..."
echo ""

timeout 35 bpftrace -e "
kprobe:vfs_read /pid == $IO_PID/ {
    printf(\"[%s] %s[%d] vfs_read(%d bytes)\\n\",
           strftime(\"%H:%M:%S\", nsecs), comm, pid, arg2);
    @read_count++;
    @read_bytes += arg2;
}

kprobe:vfs_write /pid == $IO_PID/ {
    printf(\"[%s] %s[%d] vfs_write(%d bytes)\\n\",
           strftime(\"%H:%M:%S\", nsecs), comm, pid, arg2);
    @write_count++;
    @write_bytes += arg2;
}

END {
    printf(\"\\n=== 进程 $IO_PID I/O 统计 ===\\n\");
    printf(\"读操作: %d 次, %d bytes (%.2f KB)\\n\",
           @read_count, @read_bytes, @read_bytes / 1024.0);
    printf(\"写操作: %d 次, %d bytes (%.2f KB)\\n\",
           @write_count, @write_bytes, @write_bytes / 1024.0);
}
" &
TRACE_PID=$!

wait $IO_PID 2>/dev/null
wait $TRACE_PID 2>/dev/null

cat /tmp/io_gen.log
rm -f /tmp/io_gen.log

echo ""
echo "测试场景 3: I/O 大小分布"
echo "======================"
echo ""

(
echo "跟踪 I/O 大小分布 (30秒)..."
echo ""
timeout 30 bpftrace -e '
kprobe:vfs_write {
    @write_size = hist(arg2);
    @write_total += arg2;
}

kprobe:vfs_read {
    @read_size = hist(arg2);
    @read_total += arg2;
}

END {
    printf("\n=== 写操作大小分布 ===\n");
    print(@write_size);
    printf("\n=== 读操作大小分布 ===\n");
    print(@read_size);
    printf("\n=== 总计 ===\n");
    printf("写入总量: %.2f KB\n", @write_total / 1024.0);
    printf("读取总量: %.2f KB\n", @read_total / 1024.0);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 io_generator (读操作，25次，每次4KB)..."
echo ""
./io_generator read 25 4096

wait $TRACE_PID 2>/dev/null

echo ""
echo "测试场景 4: 文件系统延迟"
echo "======================"
echo ""

(
echo "跟踪 VFS 操作延迟 (30秒)..."
echo ""
timeout 30 bpftrace -e '
kprobe:vfs_write {
    @start_write[tid] = nsecs;
}

kretprobe:vfs_write /@start_write[tid]/ {
    $latency_us = (nsecs - @start_write[tid]) / 1000;
    @write_latency = hist($latency_us);
    delete(@start_write[tid]);
}

kprobe:vfs_read {
    @start_read[tid] = nsecs;
}

kretprobe:vfs_read /@start_read[tid]/ {
    $latency_us = (nsecs - @start_read[tid]) / 1000;
    @read_latency = hist($latency_us);
    delete(@start_read[tid]);
}

END {
    printf("\n=== VFS Write 延迟分布 (微秒) ===\n");
    print(@write_latency);
    printf("\n=== VFS Read 延迟分布 (微秒) ===\n");
    print(@read_latency);
    clear(@start_write);
    clear(@start_read);
}
'
) &
TRACE_PID=$!

sleep 3

echo "运行 io_generator (写操作，15次，每次16KB)..."
echo ""
./io_generator write 15 16384

wait $TRACE_PID 2>/dev/null

echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果说明:"
echo "  1. VFS 操作统计: vfs_read/vfs_write 调用次数和字节数"
echo "  2. 进程 I/O: 特定进程的读写活动"
echo "  3. I/O 大小分布: 直方图显示操作大小分布"
echo "  4. 延迟分析: VFS 操作的时间开销"
echo ""
echo "io_generator 说明:"
echo "  - write 模式: 创建文件并写入数据"
echo "  - read 模式: 先创建文件，再读取数据"
echo "  - 每次操作都有 10ms 间隔便于观察"
echo ""
