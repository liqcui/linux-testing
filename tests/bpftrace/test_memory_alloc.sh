#!/bin/bash
# test_memory_alloc.sh - 大内存分配跟踪测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCK_DIR="$SCRIPT_DIR/mock_programs"

echo "================================"
echo "bpftrace 内存分配跟踪测试"
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
if [[ ! -f memory_allocator ]]; then
    echo "编译 memory_allocator..."
    make memory_allocator
fi

echo "测试场景 1: 跟踪大内存分配 (>1MB)"
echo "=================================="
echo ""
echo "memory_allocator 将分配 10 次 2MB 内存块"
echo ""

# 查找 libc 路径
LIBC_PATH=$(find /lib /lib64 /usr/lib -name "libc.so.6" 2>/dev/null | head -1)
if [[ -z "$LIBC_PATH" ]]; then
    # macOS 或其他系统
    LIBC_PATH="/usr/lib/system/libsystem_malloc.dylib"
    if [[ ! -f "$LIBC_PATH" ]]; then
        echo "警告: 未找到 libc，将使用内核 kmalloc 跟踪"
        USE_KMALLOC=1
    fi
fi

if [[ -z "$USE_KMALLOC" ]]; then
    echo "使用 libc 路径: $LIBC_PATH"
    echo ""

    # 启动跟踪
    (
    echo "开始跟踪 malloc (>1MB)..."
    timeout 60 bpftrace -e "
    uprobe:$LIBC_PATH:malloc /arg0 > 1048576/ {
        printf(\"%s[%d] malloc(%d bytes = %.2f MB)\\n\",
               comm, pid, arg0, arg0 / 1048576.0);
        @alloc_size = hist(arg0);
        @alloc_count++;
        @total_bytes += arg0;
    }

    END {
        printf(\"\\n=== malloc 统计 (>1MB) ===\\n\");
        printf(\"总分配次数: %d\\n\", @alloc_count);
        printf(\"总分配大小: %.2f MB\\n\", @total_bytes / 1048576.0);
        printf(\"\\n分配大小分布:\\n\");
        print(@alloc_size);
    }
    "
    ) &
    TRACE_PID=$!
else
    echo "使用内核 kmalloc 跟踪..."
    echo ""

    (
    echo "开始跟踪 kmalloc (>1MB)..."
    timeout 60 bpftrace -e "
    kprobe:__kmalloc /arg1 > 1048576/ {
        printf(\"%s[%d] kmalloc(%d bytes = %.2f MB)\\n\",
               comm, pid, arg1, arg1 / 1048576.0);
        @alloc_size = hist(arg1);
        @alloc_count++;
    }

    END {
        printf(\"\\n=== kmalloc 统计 (>1MB) ===\\n\");
        printf(\"总分配次数: %d\\n\", @alloc_count);
        printf(\"\\n分配大小分布:\\n\");
        print(@alloc_size);
    }
    "
    ) &
    TRACE_PID=$!
fi

sleep 3

# 运行内存分配程序
echo "运行 memory_allocator..."
echo ""
echo "分配 10 次，每次 2MB..."
./memory_allocator 10 2097152 <<< ""  # 自动按回车

wait $TRACE_PID 2>/dev/null

echo ""
echo "测试场景 2: 按进程跟踪内存分配"
echo "==============================="
echo ""

# 先启动程序获取 PID
./memory_allocator 5 3145728 > /tmp/mem_alloc.log 2>&1 &
MEM_PID=$!
echo "memory_allocator PID: $MEM_PID"
sleep 2

echo ""
echo "开始跟踪特定进程的大内存分配..."
echo ""

if [[ -z "$USE_KMALLOC" ]]; then
    timeout 30 bpftrace -e "
    uprobe:$LIBC_PATH:malloc /pid == $MEM_PID && arg0 > 1048576/ {
        printf(\"[%s] malloc(%d bytes = %.2f MB) at %p\\n\",
               strftime(\"%H:%M:%S\", nsecs),
               arg0, arg0 / 1048576.0, retval);
        @[\"Total MB\"] += arg0 / 1048576;
    }

    uprobe:$LIBC_PATH:free /pid == $MEM_PID/ {
        printf(\"[%s] free(%p)\\n\",
               strftime(\"%H:%M:%S\", nsecs), arg0);
    }

    END {
        printf(\"\\n=== 进程 %d 内存统计 ===\\n\", $MEM_PID);
        print(@);
    }
    " &
    TRACE_PID=$!
else
    echo "内核模式暂不支持 PID 过滤的 malloc/free 跟踪"
    TRACE_PID=""
fi

# 给程序发送回车继续执行
sleep 5
echo "" > /proc/$MEM_PID/fd/0 2>/dev/null || kill -CONT $MEM_PID 2>/dev/null

wait $MEM_PID 2>/dev/null
[[ -n "$TRACE_PID" ]] && wait $TRACE_PID 2>/dev/null

cat /tmp/mem_alloc.log
rm -f /tmp/mem_alloc.log

echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果说明:"
echo "  - 第一个测试跟踪所有 >1MB 的内存分配"
echo "  - 第二个测试跟踪特定进程的分配和释放"
echo "  - 直方图显示分配大小的分布"
echo "  - memory_allocator 默认分配 2MB 块"
echo ""
echo "典型输出:"
echo "  malloc(2097152 bytes = 2.00 MB)  - 单次分配"
echo "  @alloc_count: 10                 - 总次数"
echo "  @total_bytes: 20971520 (20 MB)   - 总大小"
echo ""
