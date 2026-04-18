#!/bin/bash
# test_comprehensive_stress.sh - 综合压力测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/stress-ng-comprehensive-$$"

echo "========================================"
echo "stress-ng 综合压力测试"
echo "========================================"
echo ""

# 检查 stress-ng
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    exit 1
fi

# 创建测试目录
mkdir -p "$TEST_DIR"

CPU_COUNT=$(nproc)
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
TEST_MEM_MB=$((TOTAL_MEM_MB * 60 / 100))  # 使用60%内存

echo "系统信息:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  主机名:     $(hostname)"
echo "  内核:       $(uname -r)"
echo "  CPU核心数:  $CPU_COUNT"
echo "  总内存:     ${TOTAL_MEM_MB} MB"
echo "  测试内存:   ${TEST_MEM_MB} MB (60%)"
echo "  测试目录:   $TEST_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "测试场景 1: CPU + 内存 综合压力"
echo "==============================="
echo ""
echo "运行参数:"
echo "  --cpu $CPU_COUNT              # 所有CPU核心"
echo "  --vm 4                        # 4个内存进程"
echo "  --vm-bytes ${TEST_MEM_MB}M    # 内存使用量"
echo "  --timeout 60s                 # 运行60秒"
echo ""

echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
stress-ng --cpu $CPU_COUNT --vm 4 --vm-bytes ${TEST_MEM_MB}M --timeout 60s --metrics-brief
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo ""
echo "测试场景 2: CPU + 内存 + I/O 综合压力"
echo "====================================="
echo ""
echo "运行参数:"
echo "  --cpu $CPU_COUNT              # 所有CPU核心"
echo "  --vm 2                        # 2个内存进程"
echo "  --vm-bytes 512M               # 每进程512M"
echo "  --io 4                        # 4个I/O进程"
echo "  --hdd 2                       # 2个硬盘I/O进程"
echo "  --timeout 60s                 # 运行60秒"
echo ""

echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
stress-ng --cpu $CPU_COUNT --vm 2 --vm-bytes 512M --io 4 --hdd 2 \
          --temp-path "$TEST_DIR" --timeout 60s --metrics-brief
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo ""
echo "测试场景 3: 全系统压力测试（所有资源）"
echo "====================================="
echo ""
echo "运行参数:"
echo "  --cpu $CPU_COUNT              # CPU压力"
echo "  --vm 2                        # 内存压力"
echo "  --io 2                        # I/O压力"
echo "  --hdd 2                       # 硬盘压力"
echo "  --sock 2                      # 网络压力"
echo "  --fork 2                      # 进程创建压力"
echo "  --timeout 90s                 # 运行90秒"
echo ""

echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
stress-ng --cpu $CPU_COUNT --vm 2 --vm-bytes 512M --io 2 --hdd 2 \
          --sock 2 --fork 2 --temp-path "$TEST_DIR" --timeout 90s --metrics-brief
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo ""
echo "测试场景 4: 高强度短时压力（峰值负载）"
echo "====================================="
echo ""
echo "模拟突发高负载场景"
echo ""

for i in {1..3}; do
    echo ""
    echo "第 $i 轮峰值负载（30秒）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    stress-ng --cpu $((CPU_COUNT * 2)) --vm 4 --vm-bytes 256M --io 4 \
              --timeout 30s --metrics-brief

    echo ""
    echo "冷却期（15秒）..."
    sleep 15
done

echo ""
echo ""
echo "测试场景 5: 持久稳定性测试（低强度长时间）"
echo "========================================="
echo ""
echo "运行参数:"
echo "  --cpu $((CPU_COUNT / 2))      # 50% CPU"
echo "  --vm 1                        # 1个内存进程"
echo "  --io 1                        # 1个I/O进程"
echo "  --timeout 120s                # 运行120秒"
echo ""

echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
stress-ng --cpu $((CPU_COUNT / 2)) --vm 1 --vm-bytes 256M --io 1 \
          --temp-path "$TEST_DIR" --timeout 120s --metrics-brief
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo ""
echo "测试场景 6: 资源争用测试"
echo "======================="
echo ""
echo "测试多进程对共享资源的争用"
echo ""

echo "6.1: 文件锁争用"
echo "---------------"
stress-ng --flock 8 --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "6.2: 信号量争用"
echo "---------------"
stress-ng --sem 8 --sem-procs 64 --timeout 30s --metrics-brief

echo ""
echo ""
echo "6.3: 消息队列压力"
echo "-----------------"
stress-ng --mq 4 --mq-size 32 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 7: 上下文切换压力"
echo "========================="
echo ""

echo "测试: 高频上下文切换"
echo "-------------------"
stress-ng --switch 8 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试: 进程调度压力"
echo "-----------------"
stress-ng --fork 16 --timeout 30s --metrics-brief

echo ""
echo ""
echo "测试场景 8: 分阶段综合压力"
echo "========================="
echo ""

PHASES=(
    "cpu:$CPU_COUNT:CPU密集阶段"
    "vm:4:内存密集阶段"
    "io:4:I/O密集阶段"
    "sock:4:网络密集阶段"
)

for phase_info in "${PHASES[@]}"; do
    IFS=':' read -r stressor workers description <<< "$phase_info"

    echo ""
    echo "$description ($stressor x $workers, 45秒)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    case $stressor in
        cpu)
            stress-ng --cpu $workers --timeout 45s --metrics-brief
            ;;
        vm)
            stress-ng --vm $workers --vm-bytes 512M --timeout 45s --metrics-brief
            ;;
        io)
            stress-ng --io $workers --temp-path "$TEST_DIR" --timeout 45s --metrics-brief
            ;;
        sock)
            stress-ng --sock $workers --timeout 45s --metrics-brief
            ;;
    esac

    echo ""
    echo "阶段间冷却（10秒）..."
    sleep 10
done

echo ""
echo ""
echo "测试场景 9: 类生产环境模拟"
echo "========================="
echo ""
echo "模拟真实生产环境的混合负载"
echo ""

(
    echo "后台任务: CPU计算（整个测试期间）"
    stress-ng --cpu 2 --cpu-method matrix --timeout 180s >/dev/null 2>&1 &
    BG_CPU=$!

    sleep 5

    echo "前台任务 1: 数据库模拟（I/O + 内存）"
    stress-ng --hdd 2 --hdd-opts fsync --vm 2 --vm-bytes 256M \
              --temp-path "$TEST_DIR" --timeout 60s --metrics-brief

    echo ""
    echo "前台任务 2: Web服务模拟（网络 + CPU）"
    stress-ng --sock 4 --cpu 2 --timeout 60s --metrics-brief

    echo ""
    echo "前台任务 3: 批处理模拟（CPU + I/O）"
    stress-ng --cpu 4 --io 4 --temp-path "$TEST_DIR" --timeout 60s --metrics-brief

    wait $BG_CPU
)

# 清理测试目录
rm -rf "$TEST_DIR"

echo ""
echo ""
echo "========================================"
echo "测试完成！"
echo "========================================"
echo ""
echo "综合压力测试结果分析:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 测试覆盖范围:"
echo "   ✓ CPU计算压力      - 各种算法和负载级别"
echo "   ✓ 内存压力         - 分配、访问、页面错误"
echo "   ✓ I/O压力          - 同步、异步、直接I/O"
echo "   ✓ 网络压力         - TCP、UDP、Socket"
echo "   ✓ 进程/线程压力    - 创建、调度、上下文切换"
echo "   ✓ 资源争用         - 文件锁、信号量、消息队列"
echo ""
echo "2. 测试模式:"
echo "   • 单一资源压力     - 测试特定子系统极限"
echo "   • 多资源并发压力   - 测试资源竞争"
echo "   • 峰值负载         - 测试突发处理能力"
echo "   • 持续负载         - 测试稳定性"
echo "   • 分阶段负载       - 测试不同场景切换"
echo ""
echo "3. 关键性能指标对比:"
echo "   CPU密集:   usr time > sys time (用户态为主)"
echo "   I/O密集:   sys time > usr time (内核态为主)"
echo "   内存密集:  大量页面错误，高 sys time"
echo "   网络密集:  高 sys time，协议栈开销"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "性能瓶颈识别:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• CPU瓶颈特征:"
echo "  - 高 usr time，接近 100% CPU"
echo "  - load average 接近或超过核心数"
echo "  - bogo ops/s 随核心数线性增长"
echo ""
echo "• 内存瓶颈特征:"
echo "  - 大量页面错误 (page faults)"
echo "  - swap使用增加"
echo "  - 性能随内存增加显著下降"
echo ""
echo "• I/O瓶颈特征:"
echo "  - 高 iowait (wa%)"
echo "  - I/O操作延迟增加"
echo "  - 磁盘队列深度增加"
echo ""
echo "• 网络瓶颈特征:"
echo "  - 高 sys time (协议栈处理)"
echo "  - 网络缓冲区溢出"
echo "  - 丢包率增加"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "监控建议:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "在另一个终端运行以下命令进行实时监控:"
echo ""
echo "• 系统总览:"
echo "    htop                    # 交互式进程查看器"
echo "    top                     # 传统进程监控"
echo ""
echo "• CPU监控:"
echo "    mpstat -P ALL 1         # 每个CPU的统计"
echo "    sar -u 1                # CPU使用率"
echo ""
echo "• 内存监控:"
echo "    vmstat 1                # 虚拟内存统计"
echo "    free -h -s 1            # 内存使用"
echo "    watch -n1 'cat /proc/meminfo | head -20'"
echo ""
echo "• I/O监控:"
echo "    iostat -x 1             # I/O统计"
echo "    iotop -o                # I/O进程监控"
echo ""
echo "• 网络监控:"
echo "    iftop                   # 网络流量"
echo "    nload                   # 网络负载"
echo "    ss -s                   # Socket统计"
echo ""
echo "• 综合监控:"
echo "    dstat -tcmndylp         # 全面系统统计"
echo "    glances                 # 综合监控工具"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "压力测试最佳实践:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 测试前准备:"
echo "   • 关闭不必要的服务"
echo "   • 确保足够的磁盘空间"
echo "   • 备份重要数据"
echo "   • 记录基准性能指标"
echo ""
echo "2. 测试执行:"
echo "   • 从低强度开始逐步增加"
echo "   • 每次测试间留冷却时间"
echo "   • 同时监控系统日志"
echo "   • 记录异常和错误"
echo ""
echo "3. 结果分析:"
echo "   • 对比不同场景的指标"
echo "   • 识别性能瓶颈"
echo "   • 评估系统稳定性"
echo "   • 生成性能报告"
echo ""
echo "4. 安全注意:"
echo "   • 不要在生产环境直接运行高强度测试"
echo "   • 监控系统温度（避免过热）"
echo "   • 准备紧急停止方案（killall stress-ng）"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
