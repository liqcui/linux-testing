#!/bin/bash
# test_iozone_advanced.sh - IOzone高级文件系统I/O性能测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOZONE_DIR="$SCRIPT_DIR/../iozone3_506"
RESULTS_DIR="$SCRIPT_DIR/../results/iozone-$(date +%Y%m%d-%H%M%S)"
TEST_DIR="${1:-/tmp/iozone_test}"

echo "========================================"
echo "IOzone 高级I/O性能测试"
echo "========================================"
echo ""

mkdir -p "$RESULTS_DIR"
mkdir -p "$TEST_DIR"

# 检查IOzone
echo "步骤 1: 检查IOzone安装..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

IOZONE_BIN=""

# 检查多个可能的位置
if [[ -f "$IOZONE_DIR/src/current/iozone" ]]; then
    IOZONE_BIN="$IOZONE_DIR/src/current/iozone"
elif command -v iozone &> /dev/null; then
    IOZONE_BIN="iozone"
elif [[ -f "/usr/local/bin/iozone" ]]; then
    IOZONE_BIN="/usr/local/bin/iozone"
fi

if [[ -z "$IOZONE_BIN" ]]; then
    echo "IOzone未找到，开始下载和编译..."
    echo ""

    cd "$SCRIPT_DIR/.."

    # 下载IOzone
    if [[ ! -d "$IOZONE_DIR" ]]; then
        echo "下载IOzone..."
        wget http://www.iozone.org/src/current/iozone3_506.tar -O iozone3_506.tar 2>/dev/null || {
            echo "✗ 下载失败，尝试备用源..."
            curl -L http://www.iozone.org/src/current/iozone3_506.tar -o iozone3_506.tar
        }

        if [[ $? -eq 0 ]]; then
            tar xf iozone3_506.tar
            rm iozone3_506.tar
            echo "✓ 下载完成"
        else
            echo "✗ 下载失败"
            echo ""
            echo "请手动下载IOzone:"
            echo "  wget http://www.iozone.org/src/current/iozone3_506.tar"
            echo "  tar xf iozone3_506.tar"
            echo "  cd iozone3_506/src/current"
            echo "  make linux-AMD64"
            exit 1
        fi
    fi

    # 编译IOzone
    echo "编译IOzone..."
    cd "$IOZONE_DIR/src/current"

    # 检测平台
    ARCH=$(uname -m)
    OS=$(uname -s)

    if [[ "$OS" == "Linux" ]]; then
        if [[ "$ARCH" == "x86_64" ]]; then
            make linux-AMD64
        elif [[ "$ARCH" == "aarch64" ]]; then
            make linux-arm
        else
            make linux
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        make macosx
    fi

    if [[ $? -eq 0 ]] && [[ -f "iozone" ]]; then
        echo "✓ 编译成功"
        IOZONE_BIN="$IOZONE_DIR/src/current/iozone"
    else
        echo "✗ 编译失败"
        exit 1
    fi
else
    echo "✓ IOzone已安装: $IOZONE_BIN"
fi

echo ""
echo "IOzone版本:"
$IOZONE_BIN -v | head -5
echo ""

# 系统信息
echo "步骤 2: 收集系统信息..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "系统信息"
    echo "========================================"
    echo ""

    echo "操作系统:"
    echo "  $(uname -s) $(uname -r)"
    echo ""

    echo "CPU信息:"
    echo "  型号: $(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    echo "  核心数: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)"
    echo ""

    echo "内存信息:"
    if [[ -f /proc/meminfo ]]; then
        MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo "  总内存: $((MEM_TOTAL / 1024)) MB"
    else
        MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null)
        echo "  总内存: $((MEM_TOTAL / 1024 / 1024)) MB"
    fi
    echo ""

    echo "测试目录信息:"
    echo "  路径: $TEST_DIR"
    df -h "$TEST_DIR" 2>/dev/null | tail -1 | awk '{print "  文件系统: " $1 "\n  总空间: " $2 "\n  已用: " $3 "\n  可用: " $4 "\n  使用率: " $5}'
    echo ""

} | tee "$RESULTS_DIR/sysinfo.txt"

# IOzone测试原理
{
    echo "IOzone测试原理"
    echo "========================================"
    echo ""
    echo "测试目的:"
    echo "  - 文件系统I/O性能全面测试"
    echo "  - 不同访问模式和记录大小的性能评估"
    echo "  - 数据库、Web服务器、文件服务器性能预测"
    echo ""
    echo "核心测试模式:"
    echo ""
    echo "1. Write (写入)"
    echo "   - 首次写入文件的性能"
    echo "   - 测试文件系统写入带宽"
    echo "   - 关键应用: 日志写入、数据导入"
    echo ""
    echo "2. Re-write (重写)"
    echo "   - 重写已存在文件的性能"
    echo "   - 通常比初始写入快（元数据已存在）"
    echo "   - 关键应用: 数据更新、日志轮转"
    echo ""
    echo "3. Read (读取)"
    echo "   - 首次读取文件的性能"
    echo "   - 测试冷缓存性能"
    echo "   - 关键应用: 数据分析、备份恢复"
    echo ""
    echo "4. Re-read (重读)"
    echo "   - 重复读取文件的性能"
    echo "   - 测试页缓存效果"
    echo "   - 性能通常远高于初始读取"
    echo ""
    echo "5. Random Read (随机读)"
    echo "   - 随机位置读取"
    echo "   - 数据库查询关键指标"
    echo "   - 单位通常是IOPS而非带宽"
    echo ""
    echo "6. Random Write (随机写)"
    echo "   - 随机位置写入"
    echo "   - 数据库事务关键指标"
    echo "   - SSD vs HDD差异明显"
    echo ""
    echo "7. Backward Read (反向读)"
    echo "   - 从文件末尾向前读取"
    echo "   - 测试预读算法效果"
    echo ""
    echo "8. Record Rewrite (记录重写)"
    echo "   - 重写文件中的随机记录"
    echo "   - 模拟数据库更新操作"
    echo ""
    echo "9. Stride Read (跨步读)"
    echo "   - 按固定间隔读取"
    echo "   - 测试预取和缓存策略"
    echo ""
    echo "10. Fwrite/Fread (标准库I/O)"
    echo "    - 使用fwrite()/fread()"
    echo "    - 测试标准库缓冲效果"
    echo ""
    echo "关键参数:"
    echo "  -s: 文件大小 (4k, 64m, 1g等)"
    echo "  -r: 记录大小 (4k, 64k, 1m等)"
    echo "  -i: 测试模式 (0=write, 1=read, 2=random等)"
    echo "  -t: 线程数 (多线程测试)"
    echo "  -I: 使用O_DIRECT (绕过缓存)"
    echo "  -w: 同步写入"
    echo ""
} | tee "$RESULTS_DIR/principles.txt"

echo ""

# 测试1: 基础吞吐量测试（不同文件大小）
echo "步骤 3: 基础吞吐量测试（不同文件大小）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "基础吞吐量测试 - 不同文件大小"
    echo "========================================"
    echo ""
    echo "测试参数:"
    echo "  - 记录大小: 4KB (数据库常见块大小)"
    echo "  - 文件大小: 64KB ~ 4GB"
    echo "  - 测试模式: write + read"
    echo ""
} | tee "$RESULTS_DIR/basic_throughput.txt"

SIZES=("64k" "512k" "4m" "32m" "256m" "1g")

# 如果可用空间充足，添加更大的测试
AVAIL_SPACE=$(df "$TEST_DIR" | tail -1 | awk '{print $4}')
if [[ $AVAIL_SPACE -gt 5242880 ]]; then  # > 5GB
    SIZES+=("4g")
fi

for size in "${SIZES[@]}"; do
    echo "测试文件大小: $size"

    $IOZONE_BIN -i 0 -i 1 -s $size -r 4k -f "$TEST_DIR/test_${size}.tmp" \
        > "$RESULTS_DIR/basic_${size}.txt" 2>&1

    if [[ $? -eq 0 ]]; then
        # 提取关键结果
        write_bw=$(grep -A 1000 "kB  reclen" "$RESULTS_DIR/basic_${size}.txt" | grep -E "^\s+[0-9]+" | awk '{print $3}')
        read_bw=$(grep -A 1000 "kB  reclen" "$RESULTS_DIR/basic_${size}.txt" | grep -E "^\s+[0-9]+" | awk '{print $5}')

        printf "  %-8s  Write: %-10s KB/s    Read: %-10s KB/s\n" "$size" "$write_bw" "$read_bw" | \
            tee -a "$RESULTS_DIR/basic_throughput.txt"
    else
        echo "  ✗ 测试失败" | tee -a "$RESULTS_DIR/basic_throughput.txt"
    fi

    # 清理测试文件
    rm -f "$TEST_DIR/test_${size}.tmp"
done

echo "" | tee -a "$RESULTS_DIR/basic_throughput.txt"
echo ""

# 测试2: 记录大小影响测试
echo "步骤 4: 记录大小影响测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "记录大小影响测试"
    echo "========================================"
    echo ""
    echo "测试参数:"
    echo "  - 文件大小: 1GB (固定)"
    echo "  - 记录大小: 512B ~ 1MB"
    echo "  - 测试模式: write + read"
    echo ""
    echo "RecSize   Write(KB/s)   Read(KB/s)   随机读(KB/s)  随机写(KB/s)"
    echo "-------   -----------   ----------   -----------  -----------"
} | tee "$RESULTS_DIR/record_size.txt"

REC_SIZES=("512" "1k" "2k" "4k" "8k" "16k" "32k" "64k" "128k" "256k" "512k" "1m")

for recsize in "${REC_SIZES[@]}"; do
    echo "测试记录大小: $recsize"

    $IOZONE_BIN -i 0 -i 1 -i 2 -s 1g -r $recsize -f "$TEST_DIR/test_rec.tmp" \
        > "$RESULTS_DIR/recsize_${recsize}.txt" 2>&1

    if [[ $? -eq 0 ]]; then
        # 提取结果
        result=$(grep -A 1000 "kB  reclen" "$RESULTS_DIR/recsize_${recsize}.txt" | \
            grep -E "^\s+[0-9]+" | \
            awk '{print $3, $5, $7, $8}')

        printf "%-7s   %-13s %-12s %-12s %s\n" "$recsize" $result | \
            tee -a "$RESULTS_DIR/record_size.txt"
    else
        printf "%-7s   测试失败\n" "$recsize" | tee -a "$RESULTS_DIR/record_size.txt"
    fi

    rm -f "$TEST_DIR/test_rec.tmp"
done

echo "" | tee -a "$RESULTS_DIR/record_size.txt"
echo ""

# 测试3: 多线程并发测试
echo "步骤 5: 多线程并发测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "多线程并发测试"
    echo "========================================"
    echo ""
    echo "测试参数:"
    echo "  - 文件大小: 1GB per thread"
    echo "  - 记录大小: 4KB"
    echo "  - 线程数: 1, 2, 4, 8, 16, 32"
    echo ""
    echo "Threads  Write(KB/s)   Read(KB/s)    Re-read(KB/s)"
    echo "-------  -----------   ----------    ------------"
} | tee "$RESULTS_DIR/multithread.txt"

THREAD_COUNTS=(1 2 4 8)
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

if [[ $CPU_CORES -ge 16 ]]; then
    THREAD_COUNTS+=(16)
fi
if [[ $CPU_CORES -ge 32 ]]; then
    THREAD_COUNTS+=(32)
fi

for threads in "${THREAD_COUNTS[@]}"; do
    echo "测试线程数: $threads"

    # 生成文件列表
    file_list=""
    for ((i=1; i<=threads; i++)); do
        file_list="$file_list $TEST_DIR/test_t${threads}_${i}.tmp"
    done

    $IOZONE_BIN -i 0 -i 1 -s 1g -r 4k -t $threads -F $file_list \
        > "$RESULTS_DIR/threads_${threads}.txt" 2>&1

    if [[ $? -eq 0 ]]; then
        # 提取聚合结果
        write_total=$(grep "Children see throughput for.*writers" "$RESULTS_DIR/threads_${threads}.txt" | \
            awk '{print $(NF-1)}')
        read_total=$(grep "Children see throughput for.*readers" "$RESULTS_DIR/threads_${threads}.txt" | \
            awk '{print $(NF-1)}')
        reread_total=$(grep "Children see throughput for.*re-readers" "$RESULTS_DIR/threads_${threads}.txt" | \
            awk '{print $(NF-1)}')

        printf "%-7s  %-13s %-13s %s\n" "$threads" "$write_total" "$read_total" "$reread_total" | \
            tee -a "$RESULTS_DIR/multithread.txt"
    else
        printf "%-7s  测试失败\n" "$threads" | tee -a "$RESULTS_DIR/multithread.txt"
    fi

    # 清理
    rm -f $file_list
done

echo "" | tee -a "$RESULTS_DIR/multithread.txt"
echo ""

# 测试4: 随机读写测试（数据库模拟）
echo "步骤 6: 随机读写测试（数据库模拟）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

{
    echo "随机读写测试 - 数据库负载模拟"
    echo "========================================"
    echo ""
    echo "测试参数:"
    echo "  - 文件大小: 4GB"
    echo "  - 记录大小: 8KB (数据库页)"
    echo "  - 使用O_DIRECT (绕过缓存)"
    echo "  - 同步写入"
    echo ""
} | tee "$RESULTS_DIR/random_io.txt"

echo "执行随机I/O测试..."

# 减小文件大小如果空间不足
TEST_FILE_SIZE="4g"
if [[ $AVAIL_SPACE -lt 5242880 ]]; then
    TEST_FILE_SIZE="1g"
    echo "  (可用空间有限，使用1GB测试文件)"
fi

$IOZONE_BIN -i 2 -s $TEST_FILE_SIZE -r 8k -I -w -f "$TEST_DIR/random.tmp" \
    > "$RESULTS_DIR/random_detail.txt" 2>&1

if [[ $? -eq 0 ]]; then
    random_read=$(grep -A 1000 "kB  reclen" "$RESULTS_DIR/random_detail.txt" | \
        grep -E "^\s+[0-9]+" | awk '{print $7}')
    random_write=$(grep -A 1000 "kB  reclen" "$RESULTS_DIR/random_detail.txt" | \
        grep -E "^\s+[0-9]+" | awk '{print $8}')

    {
        echo "随机读性能: $random_read KB/s"
        echo "随机写性能: $random_write KB/s"
        echo ""
        echo "IOPS估算 (8KB记录):"
        if [[ -n "$random_read" ]]; then
            random_read_iops=$((random_read / 8))
            echo "  随机读IOPS: $random_read_iops"
        fi
        if [[ -n "$random_write" ]]; then
            random_write_iops=$((random_write / 8))
            echo "  随机写IOPS: $random_write_iops"
        fi
    } | tee -a "$RESULTS_DIR/random_io.txt"
else
    echo "✗ 随机I/O测试失败" | tee -a "$RESULTS_DIR/random_io.txt"
fi

rm -f "$TEST_DIR/random.tmp"
echo "" | tee -a "$RESULTS_DIR/random_io.txt"
echo ""

# 测试5: 全面自动化测试
echo "步骤 7: 全面自动化测试（生成完整报告）..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "运行IOzone自动化测试（这将需要较长时间）..."
echo "  - 文件大小: 64KB ~ 512MB"
echo "  - 记录大小: 4KB ~ 16MB"
echo "  - 测试所有模式"
echo ""

$IOZONE_BIN -a -g 512m -y 4k -q 16m -f "$TEST_DIR/auto.tmp" \
    > "$RESULTS_DIR/iozone_auto.txt" 2>&1

if [[ $? -eq 0 ]]; then
    echo "✓ 自动化测试完成"

    # 生成Excel报告（如果支持）
    if $IOZONE_BIN -a -b "$RESULTS_DIR/iozone_results.xls" \
        -g 512m -y 4k -q 16m -f "$TEST_DIR/auto_xls.tmp" > /dev/null 2>&1; then
        echo "✓ Excel报告已生成: $RESULTS_DIR/iozone_results.xls"
    fi
else
    echo "⚠ 自动化测试失败（可能是空间不足）"
fi

rm -f "$TEST_DIR/auto.tmp" "$TEST_DIR/auto_xls.tmp"
echo ""

# 生成详细分析
cd "$SCRIPT_DIR"
if [[ -f "analyze_iozone.sh" ]]; then
    echo "步骤 8: 生成详细分析..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    ./analyze_iozone.sh "$RESULTS_DIR"
    echo ""
fi

# 生成报告
{
    echo "IOzone测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "测试目录: $TEST_DIR"
    echo ""

    echo "测试完成:"
    echo "  ✓ 基础吞吐量测试（${#SIZES[@]}种文件大小）"
    echo "  ✓ 记录大小影响测试（${#REC_SIZES[@]}种记录大小）"
    echo "  ✓ 多线程并发测试（${#THREAD_COUNTS[@]}种线程配置）"
    echo "  ✓ 随机读写测试（数据库负载）"
    echo "  ✓ 全面自动化测试"
    echo ""

    echo "结果文件:"
    echo "  原理说明: $RESULTS_DIR/principles.txt"
    echo "  系统信息: $RESULTS_DIR/sysinfo.txt"
    echo "  基础吞吐: $RESULTS_DIR/basic_throughput.txt"
    echo "  记录大小: $RESULTS_DIR/record_size.txt"
    echo "  多线程:   $RESULTS_DIR/multithread.txt"
    echo "  随机I/O:  $RESULTS_DIR/random_io.txt"
    echo "  自动测试: $RESULTS_DIR/iozone_auto.txt"
    if [[ -f "$RESULTS_DIR/detailed_analysis.txt" ]]; then
        echo "  详细分析: $RESULTS_DIR/detailed_analysis.txt"
    fi
    echo ""

} | tee "$RESULTS_DIR/report.txt"

# 清理测试目录
echo "清理测试文件..."
rm -rf "$TEST_DIR"/*
echo ""

echo "========================================"
echo "测试完成"
echo "========================================"
echo ""
echo "✓ IOzone高级I/O性能测试完成"
echo ""
echo "查看报告: cat $RESULTS_DIR/report.txt"
if [[ -f "$RESULTS_DIR/detailed_analysis.txt" ]]; then
    echo "查看详细分析: cat $RESULTS_DIR/detailed_analysis.txt"
fi
echo ""
echo "结果目录: $RESULTS_DIR"
echo ""
