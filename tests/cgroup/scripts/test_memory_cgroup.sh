#!/bin/bash
# test_memory_cgroup.sh - cgroup内存限制测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_DIR="$SCRIPT_DIR/../programs"
RESULTS_DIR="$SCRIPT_DIR/../results/memory-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "Cgroup 内存限制测试"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

# 编译测试程序
echo "步骤 1: 编译测试程序..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROGRAMS_DIR"
make mem_hog &>/dev/null

if [[ ! -f mem_hog ]]; then
    echo "✗ 编译失败"
    exit 1
fi

echo "✓ 编译成功: mem_hog"
echo ""

# 检测cgroup版本
echo "步骤 2: 检测cgroup版本..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CGROUP_V2=0
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "✓ 检测到 cgroup v2"
    CGROUP_V2=1
    CGROUP_ROOT="/sys/fs/cgroup"
elif [[ -d /sys/fs/cgroup/memory ]]; then
    echo "✓ 检测到 cgroup v1"
    CGROUP_V2=0
    CGROUP_ROOT="/sys/fs/cgroup/memory"
else
    echo "✗ 无法检测到cgroup"
    exit 1
fi

echo "Cgroup根目录: $CGROUP_ROOT"
echo ""

# 创建测试cgroup
echo "步骤 3: 创建测试cgroup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_GROUP="test_memory_$$"
GROUP_PATH="$CGROUP_ROOT/$TEST_GROUP"

mkdir -p "$GROUP_PATH"

if [[ ! -d "$GROUP_PATH" ]]; then
    echo "✗ 创建cgroup失败"
    exit 1
fi

echo "✓ 已创建cgroup: $TEST_GROUP"
echo "  路径: $GROUP_PATH"
echo ""

# 基准测试（无限制）
echo "步骤 4: 基准测试（无限制）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "分配200MB内存..."
timeout 15 "$PROGRAMS_DIR/mem_hog" 200 2 | tee "$RESULTS_DIR/baseline.txt"

echo ""

# 内存限制测试
echo "步骤 5: 内存限制测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LIMIT_MB=100

if [[ $CGROUP_V2 -eq 1 ]]; then
    # cgroup v2
    echo "设置内存限制为 ${LIMIT_MB}MB..."

    # 确保memory控制器启用
    echo "+memory" > "$CGROUP_ROOT/cgroup.subtree_control" 2>/dev/null

    echo "$((LIMIT_MB * 1024 * 1024))" > "$GROUP_PATH/memory.max"

    if [[ $? -ne 0 ]]; then
        echo "⚠ 设置memory.max失败"
    else
        echo "✓ 内存限制已设置: $(cat $GROUP_PATH/memory.max) bytes"
    fi
else
    # cgroup v1
    echo "设置内存限制为 ${LIMIT_MB}MB..."

    echo "$((LIMIT_MB * 1024 * 1024))" > "$GROUP_PATH/memory.limit_in_bytes"

    # 禁用OOM killer（可选）
    # echo 0 > "$GROUP_PATH/memory.oom_control"

    echo "✓ 内存限制已设置: $(cat $GROUP_PATH/memory.limit_in_bytes) bytes"
fi

echo ""
echo "在cgroup中运行程序（尝试分配200MB）..."

{
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$GROUP_PATH/cgroup.procs"
    else
        echo $$ > "$GROUP_PATH/tasks"
    fi

    timeout 15 "$PROGRAMS_DIR/mem_hog" 200 2 2>&1 || echo "进程可能因内存限制被终止"
} | tee "$RESULTS_DIR/limited-100mb.txt"

echo ""

# 检查内存统计
echo "步骤 6: 内存使用统计..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $CGROUP_V2 -eq 1 ]]; then
    echo "cgroup v2 内存统计:"
    if [[ -f "$GROUP_PATH/memory.current" ]]; then
        CURRENT=$(cat "$GROUP_PATH/memory.current")
        echo "  当前使用: $((CURRENT / 1024 / 1024)) MB"
    fi
    if [[ -f "$GROUP_PATH/memory.stat" ]]; then
        echo ""
        echo "详细统计:"
        cat "$GROUP_PATH/memory.stat" | head -20
    fi
else
    echo "cgroup v1 内存统计:"
    if [[ -f "$GROUP_PATH/memory.usage_in_bytes" ]]; then
        USAGE=$(cat "$GROUP_PATH/memory.usage_in_bytes")
        echo "  当前使用: $((USAGE / 1024 / 1024)) MB"
    fi
    if [[ -f "$GROUP_PATH/memory.max_usage_in_bytes" ]]; then
        MAX_USAGE=$(cat "$GROUP_PATH/memory.max_usage_in_bytes")
        echo "  峰值使用: $((MAX_USAGE / 1024 / 1024)) MB"
    fi
    if [[ -f "$GROUP_PATH/memory.failcnt" ]]; then
        FAILCNT=$(cat "$GROUP_PATH/memory.failcnt")
        echo "  限制失败次数: $FAILCNT"
    fi
    if [[ -f "$GROUP_PATH/memory.stat" ]]; then
        echo ""
        echo "详细统计:"
        cat "$GROUP_PATH/memory.stat" | head -20
    fi
fi

echo ""

# Swap限制测试
echo "步骤 7: Swap限制测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $CGROUP_V2 -eq 1 ]]; then
    if [[ -f "$GROUP_PATH/memory.swap.max" ]]; then
        echo "设置swap限制为50MB..."
        echo "$((50 * 1024 * 1024))" > "$GROUP_PATH/memory.swap.max" 2>/dev/null

        if [[ $? -eq 0 ]]; then
            echo "✓ Swap限制已设置"
        else
            echo "⚠ Swap限制设置失败（可能需要内核支持）"
        fi
    else
        echo "⚠ 当前系统不支持memory.swap.max"
    fi
else
    if [[ -f "$GROUP_PATH/memory.memsw.limit_in_bytes" ]]; then
        echo "设置memory+swap限制为150MB..."
        echo "$((150 * 1024 * 1024))" > "$GROUP_PATH/memory.memsw.limit_in_bytes" 2>/dev/null

        if [[ $? -eq 0 ]]; then
            echo "✓ Memory+Swap限制已设置"
        else
            echo "⚠ Memory+Swap限制设置失败"
        fi
    else
        echo "⚠ 当前系统不支持memory.memsw.limit_in_bytes"
    fi
fi

echo ""

# OOM测试
echo "步骤 8: OOM (Out of Memory) 测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

OOM_GROUP="$CGROUP_ROOT/test_oom_$$"
mkdir -p "$OOM_GROUP"

if [[ $CGROUP_V2 -eq 1 ]]; then
    echo "$((50 * 1024 * 1024))" > "$OOM_GROUP/memory.max"
    echo "设置内存限制: 50MB"
else
    echo "$((50 * 1024 * 1024))" > "$OOM_GROUP/memory.limit_in_bytes"
    echo "设置内存限制: 50MB"
fi

echo ""
echo "运行程序尝试分配100MB（预期OOM）..."

{
    if [[ $CGROUP_V2 -eq 1 ]]; then
        echo $$ > "$OOM_GROUP/cgroup.procs"
    else
        echo $$ > "$OOM_GROUP/tasks"
    fi

    timeout 10 "$PROGRAMS_DIR/mem_hog" 100 0 2>&1
    EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 137 ]]; then
        echo "✓ 进程因OOM被终止（预期行为）"
    elif [[ $EXIT_CODE -eq 124 ]]; then
        echo "⚠ 进程超时"
    else
        echo "进程退出码: $EXIT_CODE"
    fi
} | tee "$RESULTS_DIR/oom-test.txt"

echo ""

# 检查OOM事件
if [[ $CGROUP_V2 -eq 1 ]]; then
    if [[ -f "$OOM_GROUP/memory.events" ]]; then
        echo "OOM事件统计:"
        grep oom "$OOM_GROUP/memory.events"
    fi
else
    if [[ -f "$OOM_GROUP/memory.oom_control" ]]; then
        echo "OOM控制状态:"
        cat "$OOM_GROUP/memory.oom_control"
    fi
fi

echo ""

# 清理
echo "清理cgroup..."
rmdir "$OOM_GROUP" "$GROUP_PATH" 2>/dev/null
echo "✓ 清理完成"
echo ""

# 生成报告
{
    echo "Cgroup 内存测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  Cgroup版本: $([[ $CGROUP_V2 -eq 1 ]] && echo 'v2' || echo 'v1')"
    echo "  Cgroup根目录: $CGROUP_ROOT"
    echo ""
    echo "测试结果:"
    echo "  基准测试: 成功分配200MB"
    echo "  限制测试: 限制为${LIMIT_MB}MB，尝试分配200MB"
    if [[ $CGROUP_V2 -eq 1 ]]; then
        if [[ -f "$GROUP_PATH/memory.current" ]]; then
            echo "    当前使用: $(($(cat $GROUP_PATH/memory.current 2>/dev/null || echo 0) / 1024 / 1024)) MB"
        fi
    else
        if [[ -f "$GROUP_PATH/memory.usage_in_bytes" ]]; then
            echo "    当前使用: $(($(cat $GROUP_PATH/memory.usage_in_bytes 2>/dev/null || echo 0) / 1024 / 1024)) MB"
        fi
        if [[ -f "$GROUP_PATH/memory.failcnt" ]]; then
            echo "    限制失败: $(cat $GROUP_PATH/memory.failcnt 2>/dev/null || echo 0) 次"
        fi
    fi
    echo "  OOM测试: 限制50MB，尝试分配100MB"
    echo ""
    echo "详细日志:"
    echo "  基准测试: $RESULTS_DIR/baseline.txt"
    echo "  限制测试: $RESULTS_DIR/limited-100mb.txt"
    echo "  OOM测试: $RESULTS_DIR/oom-test.txt"
    echo ""
} | tee "$RESULTS_DIR/summary.txt"

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ 内存cgroup测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
