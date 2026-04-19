#!/bin/bash
# test_filesystem.sh - stress-ng 文件系统专项测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../results/filesystem_test_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUTPUT_DIR"

DURATION=60  # 每个测试60秒
CPU_CORES=$(nproc)
TEST_MOUNT=${TEST_MOUNT:-/tmp}  # 测试挂载点，可通过环境变量指定

# 前置检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 此脚本需要 root 权限"
   echo "使用: sudo $0"
   exit 1
fi

echo "=========================================="
echo "stress-ng 文件系统专项测试"
echo "=========================================="
echo ""
echo "配置:"
echo "  CPU 核心: $CPU_CORES"
echo "  测试时长: ${DURATION}秒/测试"
echo "  测试路径: $TEST_MOUNT"
echo "  输出目录: $OUTPUT_DIR"
echo "=========================================="
echo ""

# 检查工具
if ! command -v stress-ng &> /dev/null; then
    echo "错误: stress-ng 未安装"
    echo "安装: sudo apt-get install stress-ng"
    exit 1
fi

echo "✓ 工具检查完成"
echo ""

# 系统信息
{
    echo "系统信息"
    echo "========================================"
    echo "测试时间: $(date)"
    echo "主机名: $(hostname)"
    echo "内核: $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo ""

    # 文件系统信息
    echo "测试路径文件系统信息:"
    df -hT "$TEST_MOUNT"
    echo ""

    # 挂载选项
    echo "挂载选项:"
    mount | grep "$(df "$TEST_MOUNT" | tail -1 | awk '{print $1}')"
    echo ""

    # I/O调度器
    echo "I/O调度器:"
    for disk in /sys/block/sd*/queue/scheduler; do
        if [ -f "$disk" ]; then
            echo "  $disk: $(cat $disk)"
        fi
    done
    echo ""

    # 磁盘统计
    echo "当前磁盘统计:"
    iostat -x 1 2 | tail -n +4
    echo ""
} | tee "$OUTPUT_DIR/system_info.txt"

# ========== 测试1: HDD 文件写入压力测试 ==========
echo "=========================================="
echo "测试1: HDD 文件写入压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 文件大小: 1GB per worker"
echo "  • 测试重点: 顺序写入吞吐量"
echo ""

stress-ng --hdd 4 \
    --hdd-bytes 1G \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test1_hdd_write.log"

echo ""
echo "✓ HDD写入测试完成"
echo ""
sleep 5

# ========== 测试2: I/O 综合压力测试 ==========
echo "=========================================="
echo "测试2: I/O 综合压力测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: $CPU_CORES"
echo "  • 测试重点: 随机I/O性能 (IOPS)"
echo ""

stress-ng --io $CPU_CORES \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test2_io_comprehensive.log"

echo ""
echo "✓ I/O综合测试完成"
echo ""
sleep 5

# ========== 测试3: sync-file 同步I/O测试 ==========
echo "=========================================="
echo "测试3: sync-file 同步I/O测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 测试重点: fsync/fdatasync延迟"
echo ""

stress-ng --sync-file 4 \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test3_sync_file.log"

echo ""
echo "✓ sync-file测试完成"
echo ""
sleep 5

# ========== 测试4: dir 目录操作测试 ==========
echo "=========================================="
echo "测试4: dir 目录操作测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 目录数: 8192"
echo "  • 测试重点: 元数据操作性能"
echo ""

stress-ng --dir 4 \
    --dir-dirs 8192 \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test4_dir_ops.log"

echo ""
echo "✓ 目录操作测试完成"
echo ""
sleep 5

# ========== 测试5: flock 文件锁测试 ==========
echo "=========================================="
echo "测试5: flock 文件锁测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 8"
echo "  • 测试重点: 文件锁争用"
echo ""

stress-ng --flock 8 \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test5_flock.log"

echo ""
echo "✓ 文件锁测试完成"
echo ""
sleep 5

# ========== 测试6: dentry 目录项缓存测试 ==========
echo "=========================================="
echo "测试6: dentry 目录项缓存测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 测试重点: 目录项缓存性能"
echo ""

stress-ng --dentry 4 \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test6_dentry.log"

echo ""
echo "✓ dentry测试完成"
echo ""
sleep 5

# ========== 测试7: seek 文件seek测试 ==========
echo "=========================================="
echo "测试7: seek 文件seek测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 测试重点: 随机访问性能"
echo ""

stress-ng --seek 4 \
    --seek-size 1G \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test7_seek.log"

echo ""
echo "✓ seek测试完成"
echo ""
sleep 5

# ========== 测试8: readahead 预读测试 ==========
echo "=========================================="
echo "测试8: readahead 预读测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 文件大小: 256MB"
echo "  • 测试重点: 预读机制效率"
echo ""

stress-ng --readahead 4 \
    --readahead-bytes 256M \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test8_readahead.log"

echo ""
echo "✓ readahead测试完成"
echo ""
sleep 5

# ========== 测试9: aio 异步I/O测试 ==========
echo "=========================================="
echo "测试9: aio 异步I/O测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 请求数: 16 per worker"
echo "  • 测试重点: 异步I/O性能"
echo ""

stress-ng --aio 4 \
    --aio-requests 16 \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test9_aio.log"

echo ""
echo "✓ aio测试完成"
echo ""
sleep 5

# ========== 测试10: fallocate 文件预分配测试 ==========
echo "=========================================="
echo "测试10: fallocate 文件预分配测试"
echo "=========================================="
echo ""
echo "测试配置:"
echo "  • Worker数: 4"
echo "  • 测试重点: 文件空间预分配"
echo ""

stress-ng --fallocate 4 \
    --temp-path "$TEST_MOUNT" \
    --timeout ${DURATION}s \
    --metrics-brief \
    --times \
    2>&1 | tee "$OUTPUT_DIR/test10_fallocate.log"

echo ""
echo "✓ fallocate测试完成"
echo ""

# ========== 生成综合报告 ==========
echo "=========================================="
echo "生成综合测试报告"
echo "=========================================="
echo ""

{
    echo "stress-ng 文件系统测试报告"
    echo "========================================"
    echo ""
    echo "测试时间: $(date)"
    echo "系统: $(hostname) - $(uname -r)"
    echo "CPU 核心: $CPU_CORES"
    echo "测试路径: $TEST_MOUNT"
    echo ""

    # 文件系统类型
    fs_type=$(df -T "$TEST_MOUNT" | tail -1 | awk '{print $2}')
    echo "文件系统类型: $fs_type"
    echo ""

    echo "测试结果汇总"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 提取各测试的bogo ops/s
    extract_metric() {
        local logfile=$1
        local stressor=$2

        if [ -f "$logfile" ]; then
            # 提取bogo ops/s (real time)
            bogo_real=$(grep "^stress-ng: info:" "$logfile" | grep "$stressor" | awk '{print $(NF-1)}')

            if [ -n "$bogo_real" ]; then
                echo "$bogo_real"
            else
                echo "N/A"
            fi
        else
            echo "N/A"
        fi
    }

    printf "%-30s %20s %s\n" "测试项" "bogo ops/s (real)" "性能评级"
    echo "────────────────────────────────────────────────────────────────────────"

    # 评级函数
    get_filesystem_rating() {
        local test_type=$1
        local bogo_ops=$2
        local fs_type=$3

        if [ "$bogo_ops" = "N/A" ]; then
            echo "N/A"
            return
        fi

        case $test_type in
            hdd)
                # HDD写入性能评级取决于存储类型
                if [[ "$fs_type" == *"nvme"* ]] || [[ "$fs_type" == *"ssd"* ]]; then
                    if (( $(echo "$bogo_ops > 1000" | bc -l) )); then
                        echo "★★★★★ 优秀(NVMe)"
                    elif (( $(echo "$bogo_ops > 500" | bc -l) )); then
                        echo "★★★★☆ 良好(SATA SSD)"
                    else
                        echo "★★★☆☆ 一般"
                    fi
                else
                    if (( $(echo "$bogo_ops > 400" | bc -l) )); then
                        echo "★★★★★ 优秀(HDD)"
                    elif (( $(echo "$bogo_ops > 200" | bc -l) )); then
                        echo "★★★★☆ 良好(HDD)"
                    else
                        echo "★★★☆☆ 一般"
                    fi
                fi
                ;;
            io)
                if (( $(echo "$bogo_ops > 50000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 20000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 10000" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            sync)
                if (( $(echo "$bogo_ops > 500" | bc -l) )); then
                    echo "★★★★★ 优秀(SSD)"
                elif (( $(echo "$bogo_ops > 200" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 50" | bc -l) )); then
                    echo "★★★☆☆ 一般(HDD)"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            dir)
                if (( $(echo "$bogo_ops > 2000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 1000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 500" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            flock)
                if (( $(echo "$bogo_ops > 10000" | bc -l) )); then
                    echo "★★★★★ 优秀"
                elif (( $(echo "$bogo_ops > 5000" | bc -l) )); then
                    echo "★★★★☆ 良好"
                elif (( $(echo "$bogo_ops > 1000" | bc -l) )); then
                    echo "★★★☆☆ 一般"
                else
                    echo "★★☆☆☆ 较差"
                fi
                ;;
            *)
                echo "参考INTERPRETATION_GUIDE.md"
                ;;
        esac
    }

    # HDD写入测试
    hdd_ops=$(extract_metric "$OUTPUT_DIR/test1_hdd_write.log" "hdd")
    printf "%-30s %20s %s\n" "HDD文件写入" "$hdd_ops" "$(get_filesystem_rating hdd $hdd_ops $fs_type)"

    # I/O综合测试
    io_ops=$(extract_metric "$OUTPUT_DIR/test2_io_comprehensive.log" "io")
    printf "%-30s %20s %s\n" "I/O综合压力" "$io_ops" "$(get_filesystem_rating io $io_ops $fs_type)"

    # sync-file测试
    sync_ops=$(extract_metric "$OUTPUT_DIR/test3_sync_file.log" "sync-file")
    printf "%-30s %20s %s\n" "sync-file同步I/O" "$sync_ops" "$(get_filesystem_rating sync $sync_ops $fs_type)"

    # dir测试
    dir_ops=$(extract_metric "$OUTPUT_DIR/test4_dir_ops.log" "dir")
    printf "%-30s %20s %s\n" "dir目录操作" "$dir_ops" "$(get_filesystem_rating dir $dir_ops $fs_type)"

    # flock测试
    flock_ops=$(extract_metric "$OUTPUT_DIR/test5_flock.log" "flock")
    printf "%-30s %20s %s\n" "flock文件锁" "$flock_ops" "$(get_filesystem_rating flock $flock_ops $fs_type)"

    # dentry测试
    dentry_ops=$(extract_metric "$OUTPUT_DIR/test6_dentry.log" "dentry")
    printf "%-30s %20s %s\n" "dentry目录项缓存" "$dentry_ops" "参考INTERPRETATION_GUIDE.md"

    # seek测试
    seek_ops=$(extract_metric "$OUTPUT_DIR/test7_seek.log" "seek")
    printf "%-30s %20s %s\n" "seek随机访问" "$seek_ops" "参考INTERPRETATION_GUIDE.md"

    # readahead测试
    readahead_ops=$(extract_metric "$OUTPUT_DIR/test8_readahead.log" "readahead")
    printf "%-30s %20s %s\n" "readahead预读" "$readahead_ops" "参考INTERPRETATION_GUIDE.md"

    # aio测试
    aio_ops=$(extract_metric "$OUTPUT_DIR/test9_aio.log" "aio")
    printf "%-30s %20s %s\n" "aio异步I/O" "$aio_ops" "参考INTERPRETATION_GUIDE.md"

    # fallocate测试
    fallocate_ops=$(extract_metric "$OUTPUT_DIR/test10_fallocate.log" "fallocate")
    printf "%-30s %20s %s\n" "fallocate预分配" "$fallocate_ops" "参考INTERPRETATION_GUIDE.md"

    echo ""

    echo "关键发现"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 分析HDD写入吞吐量
    if [ -f "$OUTPUT_DIR/test1_hdd_write.log" ]; then
        throughput=$(grep "MB/sec" "$OUTPUT_DIR/test1_hdd_write.log" | awk '{print $2}' | head -1)
        if [ -n "$throughput" ]; then
            echo "• 写入吞吐量: ${throughput} MB/sec"
            throughput_value=$(echo "$throughput" | sed 's/[^0-9.]//g')

            # 根据存储类型评估
            if (( $(echo "$throughput_value > 2000" | bc -l) )); then
                echo "  评估: ★★★★★ NVMe SSD级别"
            elif (( $(echo "$throughput_value > 500" | bc -l) )); then
                echo "  评估: ★★★★☆ SATA SSD级别"
            elif (( $(echo "$throughput_value > 150" | bc -l) )); then
                echo "  评估: ★★★★☆ 优秀 (7200 RPM HDD)"
            elif (( $(echo "$throughput_value > 100" | bc -l) )); then
                echo "  评估: ★★★★☆ 良好 (HDD)"
            else
                echo "  评估: ★★★☆☆ 一般或存在碎片"
            fi
            echo ""
        fi
    fi

    # I/O统计分析
    echo "• I/O统计 (测试期间):"
    if command -v iostat &> /dev/null; then
        iostat -x 1 2 | tail -n +4 | head -5
    else
        echo "  iostat 未安装，跳过"
    fi
    echo ""

    # 文件系统特性对比
    echo "• 文件系统类型: $fs_type"
    case $fs_type in
        xfs)
            echo "  特点: 优秀的元数据性能，适合大量小文件"
            echo "  推荐: 数据库、邮件服务器"
            ;;
        ext4)
            echo "  特点: 平衡性能，广泛兼容"
            echo "  推荐: 通用用途"
            ;;
        btrfs)
            echo "  特点: 功能丰富(快照、压缩)，元数据操作较慢"
            echo "  推荐: 需要高级特性的场景"
            ;;
        zfs)
            echo "  特点: 写时复制，高可靠性，元数据开销大"
            echo "  推荐: 企业级存储"
            ;;
        *)
            echo "  其他文件系统"
            ;;
    esac
    echo ""

    # I/O调度器检查
    echo "• I/O调度器建议:"
    for disk in /sys/block/sd*/queue/scheduler; do
        if [ -f "$disk" ]; then
            current=$(cat "$disk" | grep -o '\[.*\]' | tr -d '[]')
            device=$(echo "$disk" | cut -d'/' -f4)

            echo "  $device: 当前使用 $current"

            # 根据存储类型建议
            if [[ "$current" == "mq-deadline" ]] || [[ "$current" == "none" ]]; then
                echo "    ✓ SSD推荐调度器: none 或 mq-deadline"
            elif [[ "$current" == "bfq" ]]; then
                echo "    建议: HDD使用mq-deadline可能更好"
            fi
        fi
    done
    echo ""

    echo "优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "详细的性能解读和优化建议请参考:"
    echo "  • INTERPRETATION_GUIDE.md - 文件系统测试结果解读章节"
    echo ""
    echo "常见优化方向:"
    echo ""
    echo "  1. I/O调度器优化:"
    echo "     # SSD设备"
    echo "     echo none > /sys/block/sda/queue/scheduler"
    echo "     # HDD设备"
    echo "     echo mq-deadline > /sys/block/sda/queue/scheduler"
    echo ""
    echo "  2. ext4挂载选项优化:"
    echo "     mount -o noatime,nodiratime,data=writeback,barrier=0 /dev/sda1 /mnt"
    echo "     # 注意: barrier=0 会降低数据安全性，仅测试环境使用"
    echo ""
    echo "  3. XFS挂载选项优化:"
    echo "     mount -o noatime,nodiratime,logbufs=8,logbsize=256k /dev/sda1 /mnt"
    echo ""
    echo "  4. 预读优化 (SSD可设置更大值):"
    echo "     blockdev --setra 8192 /dev/sda   # 4MB预读"
    echo ""
    echo "  5. 文件系统选择建议:"
    echo "     - 大量小文件: XFS"
    echo "     - 通用用途: ext4"
    echo "     - 需要快照/压缩: Btrfs"
    echo "     - 企业级: ZFS"
    echo ""
    echo "  6. 减少sync开销:"
    echo "     - 批量同步: 累积多个写入后一次sync"
    echo "     - 异步I/O: 使用aio避免阻塞"
    echo "     - 日志模式: ext4 data=writeback (注意数据安全)"
    echo ""

    echo "详细日志文件"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    ls -1 "$OUTPUT_DIR"/*.log 2>/dev/null | sed 's/^/  • /'
    echo ""

} | tee "$OUTPUT_DIR/filesystem_test_report.txt"

cat "$OUTPUT_DIR/filesystem_test_report.txt"

echo ""
echo "=========================================="
echo "测试完成！"
echo "=========================================="
echo ""
echo "结果保存至: $OUTPUT_DIR"
echo ""
echo "查看报告:"
echo "  cat $OUTPUT_DIR/filesystem_test_report.txt"
echo ""
echo "查看详细解读:"
echo "  cat ../INTERPRETATION_GUIDE.md"
echo ""
