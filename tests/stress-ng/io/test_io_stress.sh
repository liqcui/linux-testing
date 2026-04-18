#!/bin/bash
# test_io_stress.sh - I/O 压力测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/stress-ng-io-test-$$"

echo "================================"
echo "stress-ng I/O 压力测试"
echo "================================"
echo ""

# 检查 stress-ng
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    exit 1
fi

# 创建测试目录
mkdir -p "$TEST_DIR"

CPU_COUNT=$(nproc)
DISK_FREE_GB=$(df -BG "$TEST_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
TEST_SIZE_MB=$((DISK_FREE_GB * 1024 * 50 / 100))  # 使用50%可用空间

if [[ $TEST_SIZE_MB -gt 10240 ]]; then
    TEST_SIZE_MB=10240  # 最大10GB
fi

echo "系统信息:"
echo "  CPU 核心数: $CPU_COUNT"
echo "  测试目录: $TEST_DIR"
echo "  可用空间: ${DISK_FREE_GB} GB"
echo "  测试大小: ${TEST_SIZE_MB} MB"
echo ""

echo "测试场景 1: 同步 I/O 压力测试"
echo "============================"
echo ""
echo "运行参数:"
echo "  --io 4                    # 4个I/O工作进程"
echo "  --io-ops 100000           # 每个进程100k操作"
echo "  --temp-path $TEST_DIR     # 临时文件路径"
echo "  --metrics-brief           # 简要指标"
echo ""

stress-ng --io 4 --io-ops 100000 --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 2: 异步 I/O 压力测试"
echo "============================"
echo ""

echo "测试: aio (Asynchronous I/O)"
echo "---------------------------"
stress-ng --aio 4 --aio-requests 64 --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 3: 硬盘 I/O 测试（不同模式）"
echo "===================================="
echo ""

echo "测试 3.1: HDD 顺序写入"
echo "---------------------"
stress-ng --hdd 2 --hdd-bytes 1G --hdd-write-size 1M --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试 3.2: HDD 随机写入"
echo "---------------------"
stress-ng --hdd 2 --hdd-bytes 512M --hdd-write-size 4K --hdd-opts wr-rnd --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试 3.3: HDD 直接I/O（绕过缓存）"
echo "--------------------------------"
stress-ng --hdd 2 --hdd-bytes 512M --hdd-opts direct --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试 3.4: HDD fsync 压力"
echo "------------------------"
stress-ng --hdd 2 --hdd-bytes 256M --hdd-opts fsync --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 4: 文件系统压力"
echo "======================="
echo ""

echo "测试: 目录操作压力"
echo "-----------------"
stress-ng --dir 4 --dir-dirs 1024 --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试: 文件操作压力"
echo "-----------------"
stress-ng --dentry 4 --dentries 8192 --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 5: 文件读写混合测试"
echo "============================"
echo ""

echo "测试: 读写混合（50/50）"
echo "----------------------"
stress-ng --hdd 4 --hdd-bytes 512M --hdd-opts rd-rnd,wr-rnd --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 6: inode 压力测试"
echo "========================="
echo ""

echo "测试: 创建大量小文件"
echo "-------------------"
stress-ng --iomix 4 --iomix-bytes 256M --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 7: 缓存压力测试"
echo "======================="
echo ""

echo "测试: seek 压力（随机寻址）"
echo "--------------------------"
stress-ng --seek 4 --seek-size 64M --timeout 30s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试: 文件锁压力"
echo "---------------"
stress-ng --flock 4 --timeout 20s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 8: 综合 I/O 压力"
echo "========================"
echo ""

echo "测试: 同时运行多种 I/O 压力"
echo "--------------------------"
stress-ng --io 2 --hdd 2 --aio 2 --timeout 40s --temp-path "$TEST_DIR" --metrics-brief

echo ""
echo ""
echo "测试场景 9: I/O 性能基准测试"
echo "============================"
echo ""

echo "测试: 顺序读性能"
echo "---------------"
dd if=/dev/zero of="$TEST_DIR/test.dat" bs=1M count=1024 conv=fdatasync 2>&1 | grep -E "copied|MB/s"

echo ""
echo "测试: 顺序写性能"
echo "---------------"
dd if="$TEST_DIR/test.dat" of=/dev/null bs=1M 2>&1 | grep -E "copied|MB/s"

# 清理
rm -f "$TEST_DIR/test.dat"
rmdir "$TEST_DIR" 2>/dev/null || rm -rf "$TEST_DIR"

echo ""
echo ""
echo "================================"
echo "测试完成！"
echo "================================"
echo ""
echo "结果指标说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. I/O 测试类型:"
echo "   • io       - 同步I/O（read/write）"
echo "   • aio      - 异步I/O（Linux AIO）"
echo "   • hdd      - 硬盘I/O（顺序/随机）"
echo "   • dir      - 目录操作"
echo "   • dentry   - 目录项操作"
echo "   • iomix    - 混合I/O操作"
echo "   • seek     - 随机寻址"
echo "   • flock    - 文件锁"
echo ""
echo "2. HDD 选项:"
echo "   • direct   - 直接I/O（绕过页面缓存）"
echo "   • fsync    - 每次写入后fsync"
echo "   • rd-rnd   - 随机读"
echo "   • wr-rnd   - 随机写"
echo "   • rd-seq   - 顺序读"
echo "   • wr-seq   - 顺序写"
echo ""
echo "3. 性能指标:"
echo "   • bogo ops/s      - 每秒I/O操作数"
echo "   • MB/s            - 每秒传输速率"
echo "   • IOPS            - 每秒I/O操作数"
echo "   • latency         - I/O延迟"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "典型输出示例:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "stress-ng: info:  [12345] dispatching hogs: 4 hdd"
echo "stress-ng: info:  [12345] successful run completed in 30.00s"
echo "stress-ng: info:  [12345] stressor       bogo ops real time  usr time  sys time   bogo ops/s"
echo "stress-ng: info:  [12345] hdd               45670     30.00      2.50     28.30      1522.33"
echo ""
echo "解读:"
echo "  - 4个HDD工作进程"
echo "  - 30秒完成45670次I/O操作"
echo "  - 系统态时间28秒（I/O密集）"
echo "  - 每秒1522次I/O操作"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "性能分析:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• 顺序I/O vs 随机I/O:"
echo "  - 顺序I/O: 更高的吞吐量（MB/s）"
echo "  - 随机I/O: 更多的IOPS，但总吞吐量较低"
echo ""
echo "• Direct I/O vs Buffered I/O:"
echo "  - Direct: 绕过缓存，真实磁盘性能"
echo "  - Buffered: 使用页面缓存，性能更高但不真实"
echo ""
echo "• 同步I/O vs 异步I/O:"
echo "  - 同步: 阻塞等待I/O完成"
echo "  - 异步: 提交后立即返回，更高并发"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "监控命令:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "• iostat -x 1          # I/O统计"
echo "• iotop                # I/O进程监控"
echo "• vmstat 1             # 系统统计（含I/O）"
echo "• df -h                # 磁盘空间"
echo "• du -sh /tmp          # 目录大小"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
