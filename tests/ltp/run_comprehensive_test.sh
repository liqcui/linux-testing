#!/bin/bash
# run_comprehensive_test.sh - 运行 LTP 综合测试（约 6-8 小时）

set -e

LTP_DIR="${LTP_DIR:-/opt/ltp}"
RESULTS_DIR="./ltp-comprehensive-results-$(date +%Y%m%d-%H%M%S)"

echo "========================================"
echo "LTP 综合测试"
echo "========================================"
echo ""
echo "警告: 此测试将运行 6-8 小时"
echo "建议在测试环境运行，不要在生产环境！"
echo ""

read -p "是否继续? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "测试已取消"
    exit 0
fi

# 检查 LTP 是否已安装
if [[ ! -x "$LTP_DIR/runltp" ]]; then
    echo "错误: LTP 未安装在 $LTP_DIR"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要 root 权限"
   echo "请使用: sudo $0"
   exit 1
fi

mkdir -p "$RESULTS_DIR"

echo ""
echo "配置:"
echo "  LTP 路径:     $LTP_DIR"
echo "  结果目录:     $RESULTS_DIR"
echo "  开始时间:     $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd "$LTP_DIR"

# 创建综合测试场景
SCENARIO_FILE="$RESULTS_DIR/comprehensive-scenario"

cat > "$SCENARIO_FILE" << 'EOF'
# LTP 综合测试场景
# 涵盖所有核心子系统

# 系统调用
syscalls

# 内存管理
mm

# 文件系统
fs
fs_perms_simple
dio

# 进程调度
sched

# IPC
ipc

# 定时器
timers

# POSIX 线程
nptl

# I/O
io

# 伪终端
pty

# 容器
containers

# cgroup
cgroup

# 命名空间
namespaces

# 数学库
math

# 系统命令
commands
EOF

echo "测试场景:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$SCENARIO_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 记录系统信息
{
    echo "系统信息快照"
    echo "========================================"
    echo "日期: $(date)"
    echo "主机: $(hostname)"
    echo "内核: $(uname -a)"
    echo ""
    echo "CPU 信息:"
    lscpu
    echo ""
    echo "内存信息:"
    free -h
    echo ""
    echo "磁盘信息:"
    df -h
    echo ""
    echo "内核模块:"
    lsmod
    echo ""
} > "$RESULTS_DIR/system-info.txt"

# 运行测试
echo "开始运行测试..."
echo "预计时间: 6-8 小时"
echo ""

START_TIME=$(date +%s)

./runltp \
    -f "$SCENARIO_FILE" \
    -l "$RESULTS_DIR/test.log" \
    -o "$RESULTS_DIR/output.log" \
    -p

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))

# 分析结果
echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "结束时间:   $(date '+%Y-%m-%d %H:%M:%S')"
echo "总耗时:     ${HOURS}h ${MINUTES}m"
echo ""

# 统计结果
if [[ -f "$RESULTS_DIR/output.log" ]]; then
    TOTAL=$(grep -c "<<<test" "$RESULTS_DIR/output.log" || echo 0)
    PASS=$(grep -c "PASS" "$RESULTS_DIR/output.log" || echo 0)
    FAIL=$(grep -c "FAIL" "$RESULTS_DIR/output.log" || echo 0)
    CONF=$(grep -c "CONF" "$RESULTS_DIR/output.log" || echo 0)
    BROK=$(grep -c "BROK" "$RESULTS_DIR/output.log" || echo 0)
    WARN=$(grep -c "WARN" "$RESULTS_DIR/output.log" || echo 0)

    echo "测试结果统计:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  总测试数:     $TOTAL"
    echo "  通过 (PASS):  $PASS"
    echo "  失败 (FAIL):  $FAIL"
    echo "  配置 (CONF):  $CONF"
    echo "  中断 (BROK):  $BROK"
    echo "  警告 (WARN):  $WARN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 计算通过率
    if [[ $TOTAL -gt 0 ]]; then
        PASS_RATE=$((PASS * 100 / TOTAL))
        echo "通过率: ${PASS_RATE}%"
        echo ""
    fi

    # 失败测试详情
    if [[ $FAIL -gt 0 ]]; then
        echo "失败的测试 (前 30 个):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        grep "FAIL" "$RESULTS_DIR/output.log" | head -30
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # 提取失败测试到单独文件
        grep "FAIL" "$RESULTS_DIR/output.log" > "$RESULTS_DIR/failed-tests.txt"
        echo "失败测试保存到: $RESULTS_DIR/failed-tests.txt"
        echo ""
    fi

    # 中断测试详情
    if [[ $BROK -gt 0 ]]; then
        echo "中断的测试 (前 20 个):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        grep "BROK" "$RESULTS_DIR/output.log" | head -20
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        grep "BROK" "$RESULTS_DIR/output.log" > "$RESULTS_DIR/broken-tests.txt"
        echo "中断测试保存到: $RESULTS_DIR/broken-tests.txt"
        echo ""
    fi
fi

echo "结果文件:"
echo "  主日志:       $RESULTS_DIR/test.log"
echo "  详细输出:     $RESULTS_DIR/output.log"
echo "  系统信息:     $RESULTS_DIR/system-info.txt"
if [[ $FAIL -gt 0 ]]; then
    echo "  失败测试:     $RESULTS_DIR/failed-tests.txt"
fi
if [[ $BROK -gt 0 ]]; then
    echo "  中断测试:     $RESULTS_DIR/broken-tests.txt"
fi
echo ""

# 生成详细摘要
{
    echo "LTP 综合测试摘要报告"
    echo "========================================"
    echo ""
    echo "测试信息:"
    echo "  开始时间: $(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $START_TIME '+%Y-%m-%d %H:%M:%S')"
    echo "  结束时间: $(date -d @$END_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $END_TIME '+%Y-%m-%d %H:%M:%S')"
    echo "  总耗时:   ${HOURS}h ${MINUTES}m"
    echo ""
    echo "系统信息:"
    echo "  主机名:   $(hostname)"
    echo "  内核:     $(uname -r)"
    echo "  架构:     $(uname -m)"
    echo "  CPU:      $(nproc) 核心"
    echo "  内存:     $(free -h | awk '/^Mem:/{print $2}')"
    echo ""
    echo "测试统计:"
    echo "  总测试数:     $TOTAL"
    echo "  通过 (PASS):  $PASS"
    echo "  失败 (FAIL):  $FAIL"
    echo "  配置 (CONF):  $CONF"
    echo "  中断 (BROK):  $BROK"
    echo "  警告 (WARN):  $WARN"
    if [[ $TOTAL -gt 0 ]]; then
        echo "  通过率:       ${PASS_RATE}%"
    fi
    echo ""
    echo "测试场景:"
    cat "$SCENARIO_FILE" | grep -v "^#" | grep -v "^$"
    echo ""
    if [[ $FAIL -gt 0 ]]; then
        echo "失败测试摘要 (前 10 个):"
        grep "FAIL" "$RESULTS_DIR/output.log" | head -10
        echo ""
    fi
} > "$RESULTS_DIR/summary.txt"

cat "$RESULTS_DIR/summary.txt"

# 检查内核日志中的错误
echo "检查内核日志..."
dmesg | tail -100 > "$RESULTS_DIR/dmesg.log"
if dmesg | grep -i "bug\|oops\|panic" > "$RESULTS_DIR/kernel-errors.txt"; then
    echo "警告: 发现内核错误，已保存到 $RESULTS_DIR/kernel-errors.txt"
fi

# 建议
echo ""
echo "后续建议:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAIL -gt 0 ]]; then
    echo "  1. 查看失败测试详情: cat $RESULTS_DIR/failed-tests.txt"
    echo "  2. 重跑失败的测试: sudo ./runltp -f syscalls -r $RESULTS_DIR/output.log"
    echo "  3. 查看内核日志: cat $RESULTS_DIR/kernel-errors.txt"
fi
echo "  4. 保存测试报告以备后续对比"
echo "  5. 如果发现内核 bug，考虑向内核社区报告"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 退出状态
if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    exit 0
fi
