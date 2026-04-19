#!/bin/bash
# test_fio.sh - FIO I/O性能测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs"
RESULTS_DIR="$SCRIPT_DIR/../results/fio-$(date +%Y%m%d-%H%M%S)"
TEST_FILE="/tmp/fio-test-file"

echo "========================================"
echo "FIO I/O 性能测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"

# 检查FIO是否安装
echo "步骤 1: 检查FIO安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v fio &> /dev/null; then
    echo "✗ FIO未安装"
    echo ""
    echo "安装方法:"
    echo "  Ubuntu/Debian: sudo apt-get install fio"
    echo "  RHEL/CentOS:   sudo yum install fio"
    echo "  Fedora:        sudo dnf install fio"
    exit 1
fi

FIO_VERSION=$(fio --version)
echo "✓ FIO已安装: $FIO_VERSION"
echo ""

# FIO原理说明
echo "步骤 2: FIO测试原理..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "FIO (Flexible I/O Tester) 原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  FIO是一个灵活的I/O基准测试和压力测试工具"
    echo "  可以模拟各种I/O负载模式"
    echo ""
    echo "核心概念:"
    echo ""
    echo "1. I/O模式 (rw):"
    echo "   - read: 顺序读"
    echo "   - write: 顺序写"
    echo "   - randread: 随机读"
    echo "   - randwrite: 随机写"
    echo "   - randrw: 随机读写混合"
    echo "   - readwrite: 顺序读写混合"
    echo ""
    echo "2. 块大小 (bs):"
    echo "   - 4K: 数据库、随机I/O"
    echo "   - 128K-1M: 顺序I/O、流媒体"
    echo "   - 影响IOPS和吞吐量"
    echo ""
    echo "3. I/O深度 (iodepth):"
    echo "   - 队列中未完成的I/O请求数"
    echo "   - 低值(1-4): 测试延迟"
    echo "   - 高值(32-128): 测试吞吐量/IOPS"
    echo ""
    echo "4. I/O引擎 (ioengine):"
    echo "   - sync: 同步I/O (read/write)"
    echo "   - libaio: Linux异步I/O (推荐)"
    echo "   - io_uring: 新的异步I/O接口"
    echo "   - mmap: 内存映射"
    echo ""
    echo "5. 直接I/O (direct):"
    echo "   - direct=1: 绕过缓存(O_DIRECT)"
    echo "   - direct=0: 使用缓存"
    echo ""
    echo "关键指标:"
    echo "  - IOPS: 每秒I/O操作数"
    echo "  - 带宽: MB/s或GB/s"
    echo "  - 延迟: 平均、P50、P95、P99、最大延迟"
    echo "  - CPU使用率"
    echo ""
    echo "典型场景:"
    echo "  - 数据库: 4K随机读写, iodepth=32"
    echo "  - Web服务器: 4K-64K随机读"
    echo "  - 大数据: 1M顺序读写"
    echo "  - 虚拟化: 混合负载"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

# 检查测试目标
echo "步骤 3: 检查测试环境..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 获取测试目录的文件系统信息
TEST_DIR=$(dirname "$TEST_FILE")
FS_TYPE=$(df -T "$TEST_DIR" | tail -1 | awk '{print $2}')
FS_AVAIL=$(df -h "$TEST_DIR" | tail -1 | awk '{print $4}')

echo "测试文件: $TEST_FILE"
echo "文件系统: $FS_TYPE"
echo "可用空间: $FS_AVAIL"

# 检查是否有足够空间
AVAIL_KB=$(df "$TEST_DIR" | tail -1 | awk '{print $4}')
REQUIRED_KB=$((5 * 1024 * 1024))  # 5GB

if [[ $AVAIL_KB -lt $REQUIRED_KB ]]; then
    echo "⚠ 警告: 可用空间不足5GB，某些测试可能失败"
fi

echo ""

# 系统信息
{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "操作系统:"
    echo "  $(uname -s) $(uname -r)"

    echo ""
    echo "CPU信息:"
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    CPU_COUNT=$(grep -c processor /proc/cpuinfo)
    echo "  型号: $CPU_MODEL"
    echo "  核心数: $CPU_COUNT"

    echo ""
    echo "内存信息:"
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo "  总内存: $((MEM_TOTAL / 1024)) MB"

    echo ""
    echo "磁盘信息:"
    echo "  测试路径: $TEST_DIR"
    echo "  文件系统: $FS_TYPE"
    echo "  可用空间: $FS_AVAIL"

    # 如果是块设备，显示设备信息
    MOUNT_POINT=$(df "$TEST_DIR" | tail -1 | awk '{print $1}')
    if [[ -b "$MOUNT_POINT" ]]; then
        echo ""
        echo "块设备信息:"
        lsblk "$MOUNT_POINT" 2>/dev/null || echo "  无法获取"
    fi

} | tee "$RESULTS_DIR/sysinfo.txt"

echo ""

# 定义测试场景
declare -A TESTS=(
    ["sequential_read"]="顺序读测试"
    ["sequential_write"]="顺序写测试"
    ["random_read"]="随机读测试"
    ["random_write"]="随机写测试"
    ["mixed_rw"]="混合读写测试"
    ["iops_test"]="IOPS测试"
    ["latency_test"]="延迟测试"
)

# 运行测试
echo "步骤 4: 运行FIO测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TEST_COUNT=0
for test_name in "${!TESTS[@]}"; do
    ((TEST_COUNT++))
    desc="${TESTS[$test_name]}"
    config_file="$CONFIGS_DIR/${test_name}.fio"

    if [[ ! -f "$config_file" ]]; then
        echo "⚠ 跳过 $desc: 配置文件不存在"
        continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "测试 $TEST_COUNT: $desc"
    echo "配置: $config_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 运行FIO测试
    fio "$config_file" \
        --output="$RESULTS_DIR/${test_name}.txt" \
        --output-format=normal,json \
        --json="$RESULTS_DIR/${test_name}.json"

    if [[ $? -eq 0 ]]; then
        echo "✓ $desc 完成"
    else
        echo "✗ $desc 失败"
    fi

    echo ""

    # 清理测试文件避免占用太多空间
    rm -f "$TEST_FILE"
done

# 提取关键指标
echo "步骤 5: 提取测试结果..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "FIO测试结果汇总"
    echo "========================================"
    echo ""
    printf "%-25s %15s %15s %15s\n" "测试场景" "IOPS" "带宽(MB/s)" "延迟(us)"
    echo "------------------------------------------------------------------------"

    for test_name in sequential_read sequential_write random_read random_write mixed_rw iops_test latency_test; do
        result_file="$RESULTS_DIR/${test_name}.txt"

        if [[ ! -f "$result_file" ]]; then
            continue
        fi

        desc="${TESTS[$test_name]}"

        # 提取IOPS
        iops=$(grep "IOPS=" "$result_file" | head -1 | sed 's/.*IOPS=\([0-9.k]*\).*/\1/')

        # 提取带宽
        bw=$(grep "bw=" "$result_file" | head -1 | sed 's/.*bw=\([0-9.KMG]*\).*/\1/')

        # 提取平均延迟
        lat=$(grep "lat.*avg" "$result_file" | head -1 | awk '{print $2}' | sed 's/avg=//')

        printf "%-25s %15s %15s %15s\n" "$desc" "$iops" "$bw" "$lat"
    done

    echo ""

} | tee "$RESULTS_DIR/summary.txt"

# 性能分析
echo "步骤 6: 性能分析..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "性能分析"
    echo "========================================"
    echo ""

    echo "存储类型性能参考:"
    echo ""
    echo "HDD (机械硬盘):"
    echo "  顺序读写: 100-200 MB/s"
    echo "  随机IOPS: 100-200 IOPS"
    echo "  延迟: 5-15 ms"
    echo ""
    echo "SATA SSD:"
    echo "  顺序读写: 500-600 MB/s"
    echo "  随机IOPS: 50K-100K IOPS"
    echo "  延迟: 50-100 us"
    echo ""
    echo "NVMe SSD:"
    echo "  顺序读写: 3000-7000 MB/s"
    echo "  随机IOPS: 500K-1M IOPS"
    echo "  延迟: 10-50 us"
    echo ""
    echo "NVMe Gen4:"
    echo "  顺序读写: 5000-7000 MB/s"
    echo "  随机IOPS: 1M+ IOPS"
    echo "  延迟: < 10 us"
    echo ""

    echo "性能评估指南:"
    echo ""
    echo "1. 顺序读写:"
    echo "   - 主要受限于存储介质带宽"
    echo "   - 大块I/O (128K-1M) 性能更好"
    echo "   - 适合流媒体、备份、大数据"
    echo ""
    echo "2. 随机读写:"
    echo "   - 主要受限于IOPS"
    echo "   - 小块I/O (4K) 测试随机性能"
    echo "   - 适合数据库、虚拟化"
    echo ""
    echo "3. 延迟:"
    echo "   - 低延迟对交互式应用重要"
    echo "   - 关注P95、P99延迟"
    echo "   - 队列深度=1测试单I/O延迟"
    echo ""
    echo "4. IOPS vs 带宽:"
    echo "   - IOPS = 带宽 / 块大小"
    echo "   - 4K随机: 关注IOPS"
    echo "   - 大块顺序: 关注带宽"
    echo ""

} | tee "$RESULTS_DIR/analysis.txt"

# 优化建议
{
    echo "性能优化建议"
    echo "========================================"
    echo ""

    echo "1. 文件系统优化:"
    echo "   ext4:"
    echo "     - noatime: 禁用访问时间更新"
    echo "     - data=writeback: 异步数据写入"
    echo "     mount -o noatime,data=writeback /dev/sda1 /mnt"
    echo ""
    echo "   XFS:"
    echo "     - noatime,nodiratime"
    echo "     - largeio,swalloc"
    echo "     mount -o noatime,largeio /dev/sda1 /mnt"
    echo ""
    echo "2. I/O调度器:"
    echo "   SSD/NVMe:"
    echo "     echo none > /sys/block/nvme0n1/queue/scheduler"
    echo "     # 或使用 mq-deadline"
    echo ""
    echo "   HDD:"
    echo "     echo bfq > /sys/block/sda/queue/scheduler"
    echo "     # bfq对机械盘更友好"
    echo ""
    echo "3. 队列深度:"
    echo "   # 增加设备队列深度"
    echo "   echo 1024 > /sys/block/nvme0n1/queue/nr_requests"
    echo ""
    echo "4. 读取预读:"
    echo "   # 调整预读大小（单位：512字节扇区）"
    echo "   echo 512 > /sys/block/nvme0n1/queue/read_ahead_kb"
    echo ""
    echo "5. 虚拟内存:"
    echo "   # 减少swap使用"
    echo "   sysctl -w vm.swappiness=10"
    echo ""
    echo "   # 调整脏页刷新"
    echo "   sysctl -w vm.dirty_ratio=10"
    echo "   sysctl -w vm.dirty_background_ratio=5"
    echo ""
    echo "6. CPU频率:"
    echo "   # 性能模式"
    echo "   cpupower frequency-set -g performance"
    echo ""
    echo "7. NVMe优化:"
    echo "   # 启用write cache"
    echo "   nvme set-feature /dev/nvme0 -f 0x06 -v 1"
    echo ""
    echo "   # 调整I/O超时"
    echo "   echo 4294967295 > /sys/block/nvme0n1/queue/io_timeout"
    echo ""

} | tee "$RESULTS_DIR/optimization.txt"

# 配置说明
{
    echo "FIO配置参数说明"
    echo "========================================"
    echo ""

    echo "全局参数 [global]:"
    echo "  ioengine=libaio    # I/O引擎"
    echo "  direct=1           # 直接I/O,绕过缓存"
    echo "  iodepth=32         # 队列深度"
    echo "  runtime=60         # 运行时间(秒)"
    echo "  time_based=1       # 基于时间而非大小"
    echo "  group_reporting=1  # 汇总报告"
    echo "  numjobs=4          # 并发任务数"
    echo ""
    echo "任务参数 [job-name]:"
    echo "  rw=randread        # I/O模式"
    echo "  bs=4k              # 块大小"
    echo "  filename=/path     # 测试文件"
    echo "  size=4G            # 文件大小"
    echo ""
    echo "I/O模式 (rw):"
    echo "  read      - 顺序读"
    echo "  write     - 顺序写"
    echo "  randread  - 随机读"
    echo "  randwrite - 随机写"
    echo "  randrw    - 随机读写混合"
    echo "  readwrite - 顺序读写混合"
    echo ""
    echo "I/O引擎 (ioengine):"
    echo "  sync     - 同步I/O (read/write)"
    echo "  psync    - pread/pwrite"
    echo "  libaio   - Linux异步I/O (推荐)"
    echo "  io_uring - 新异步I/O (5.1+内核)"
    echo "  mmap     - 内存映射I/O"
    echo ""
    echo "块大小建议:"
    echo "  4K       - 数据库, 随机I/O"
    echo "  16K-64K  - 一般应用"
    echo "  128K-1M  - 顺序I/O, 流媒体"
    echo ""
    echo "队列深度建议:"
    echo "  1-4      - 测试延迟"
    echo "  16-32    - 一般性能测试"
    echo "  64-128   - 最大吞吐量测试"
    echo ""

} | tee "$RESULTS_DIR/config_guide.txt"

# 生成报告
{
    echo "FIO I/O性能测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo ""
    echo "系统信息:"
    echo "  操作系统: $(uname -s) $(uname -r)"
    echo "  CPU: $CPU_MODEL"
    echo "  内存: $((MEM_TOTAL / 1024)) MB"
    echo ""
    echo "测试配置:"
    echo "  测试路径: $TEST_DIR"
    echo "  文件系统: $FS_TYPE"
    echo "  FIO版本: $FIO_VERSION"
    echo ""
    echo "测试场景:"
    for test_name in "${!TESTS[@]}"; do
        if [[ -f "$RESULTS_DIR/${test_name}.txt" ]]; then
            echo "  ✓ ${TESTS[$test_name]}"
        fi
    done
    echo ""
    echo "结果文件:"
    echo "  测试原理: $RESULTS_DIR/principles.txt"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  结果汇总: $RESULTS_DIR/summary.txt"
    echo "  性能分析: $RESULTS_DIR/analysis.txt"
    echo "  优化建议: $RESULTS_DIR/optimization.txt"
    echo "  配置说明: $RESULTS_DIR/config_guide.txt"
    echo ""
    echo "详细结果:"
    for test_name in "${!TESTS[@]}"; do
        if [[ -f "$RESULTS_DIR/${test_name}.txt" ]]; then
            echo "  ${TESTS[$test_name]}: $RESULTS_DIR/${test_name}.txt"
        fi
    done
    echo ""

} | tee "$RESULTS_DIR/report.txt"

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ FIO I/O性能测试完成"
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
echo "查看汇总: cat $RESULTS_DIR/summary.txt"
echo ""
