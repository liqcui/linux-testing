#!/bin/bash
# analyze_iozone.sh - IOzone结果详细解读

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${1:-$SCRIPT_DIR/../results}"

# 如果没有提供结果目录，查找最新的
if [[ ! -d "$RESULTS_DIR" ]] || [[ "$RESULTS_DIR" == "$SCRIPT_DIR/../results" ]]; then
    LATEST=$(ls -td $SCRIPT_DIR/../results/iozone-* 2>/dev/null | head -1)
    if [[ -n "$LATEST" ]]; then
        RESULTS_DIR="$LATEST"
    else
        echo "错误: 未找到测试结果目录"
        exit 1
    fi
fi

ANALYSIS_FILE="$RESULTS_DIR/detailed_analysis.txt"

echo "========================================"
echo "IOzone 结果详细解读"
echo "========================================"
echo ""
echo "分析目录: $RESULTS_DIR"
echo "生成文件: $ANALYSIS_FILE"
echo ""

{
    echo "IOzone测试结果详细解读"
    echo "========================================"
    echo ""
    echo "分析时间: $(date)"
    echo "结果目录: $RESULTS_DIR"
    echo ""

    # ========== 典型输出示例 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. IOzone典型输出示例及解读"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "【典型输出格式】"
    echo "----------------------------------------"
    echo ""
    cat <<'EXAMPLE'
IOzone测试输出示例:

              KB  reclen  write rewrite  read  reread  random  random  bkwd   record  stride
                                                       read    write   read   rewrite  read
           65536       4 456789  523456 678901 789012  234567  198765 345678  287654  412345
          524288       4 523456  589012 789012 891234  278901  234567 401234  312345  456789
         4194304       4 612345  678901 891234 956789  312345  267890 478901  345678  523456

说明:
  KB      - 文件大小(KB)                  ← 测试文件大小
  reclen  - 记录大小(KB)                  ← I/O操作块大小
  write   - 初始写入(KB/s)                ← 首次创建文件写入性能
  rewrite - 重写(KB/s)                    ← 重写已存在文件性能
  read    - 初始读取(KB/s)                ← 首次读取文件性能(冷缓存)
  reread  - 重读(KB/s)                    ← 重复读取性能(热缓存)
  random read  - 随机读(KB/s)             ← 数据库查询关键指标
  random write - 随机写(KB/s)             ← 数据库事务关键指标
  bkwd read    - 反向读(KB/s)             ← 预读算法测试
  record rewrite - 记录重写(KB/s)         ← 数据库更新模拟
  stride read    - 跨步读(KB/s)           ← 稀疏访问性能

关键指标:
  ★ write vs rewrite:
    rewrite > write → 元数据已存在，性能更好
    典型: rewrite = 110-130% of write

  ★ read vs reread:
    reread >> read → 页缓存命中
    典型: reread = 200-500% of read

  ★ random vs sequential:
    random << sequential → 磁盘寻道开销
    HDD:  random = 1-5% of sequential
    SSD:  random = 40-80% of sequential
    NVMe: random = 60-90% of sequential

  ★ IOPS计算:
    IOPS = (KB/s) / (reclen)
    示例: 234567 KB/s ÷ 4 KB = 58,641 IOPS
EXAMPLE

    echo ""
    echo ""

    # ========== IOzone 13种测试模式详解 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "2. IOzone 13种测试模式详解"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cat <<'MODES'
模式0: Write (初始写入)
  操作: 创建新文件并写入数据
  特点: 包含文件创建、元数据写入、数据写入
  应用: 日志写入、数据导入、备份
  性能: 通常低于rewrite

模式1: Read (初始读取)
  操作: 首次读取文件
  特点: 冷缓存，需要从磁盘读取
  应用: 数据分析、备份恢复、首次查询
  性能: 通常远低于reread

模式2: Random Read (随机读)
  操作: 随机位置读取
  特点: 大量磁盘寻道(HDD)或随机访问(SSD)
  应用: 数据库查询、索引查找
  性能: HDD << SSD < NVMe
  单位: 常用IOPS而非带宽

模式3: Random Write (随机写)
  操作: 随机位置写入
  特点: 测试真实数据库写入性能
  应用: 数据库事务、随机更新
  性能: SSD写放大影响明显
  单位: 常用IOPS而非带宽

模式4: Re-write (重写)
  操作: 重写已存在的文件
  特点: 元数据已存在，可能复用磁盘块
  应用: 日志轮转、覆盖更新
  性能: 通常高于初始write

模式5: Re-read (重读)
  操作: 重复读取文件
  特点: 数据在页缓存中
  应用: 频繁访问的数据、缓存命中场景
  性能: 极高，受限于内存带宽

模式6: Backward Read (反向读)
  操作: 从文件末尾向开头读取
  特点: 测试预读算法有效性
  应用: 某些特殊应用场景
  性能: 通常低于顺序读

模式7: Record Rewrite (记录重写)
  操作: 重写文件中的随机记录
  特点: 模拟数据库更新操作
  应用: 数据库记录更新
  性能: 介于顺序写和随机写之间

模式8: Stride Read (跨步读)
  操作: 按固定间隔读取
  特点: 测试稀疏访问性能
  应用: 大数据集采样读取
  性能: 取决于预取策略

模式9: Fwrite (标准库写)
  操作: 使用fwrite()而非write()
  特点: 测试标准库缓冲效果
  应用: 使用标准I/O的应用
  性能: 小块I/O时可能更快

模式10: Fread (标准库读)
  操作: 使用fread()而非read()
  特点: 测试标准库缓冲效果
  应用: 使用标准I/O的应用
  性能: 小块I/O时可能更快

模式11: Pwrite (位置写)
  操作: 使用pwrite()系统调用
  特点: 原子性读写，线程安全
  应用: 多线程应用
  性能: 类似write

模式12: Pread (位置读)
  操作: 使用pread()系统调用
  特点: 原子性读写，线程安全
  应用: 多线程应用
  性能: 类似read

MODES

    echo ""

    # ========== 存储类型性能等级 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "3. 存储类型性能等级划分"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cat <<'STORAGE'
【HDD机械硬盘】
----------------------------------------

7200转 SATA HDD:
  顺序写入:   80-160 MB/s       ★☆☆☆☆
  顺序读取:   80-180 MB/s       ★☆☆☆☆
  随机读IOPS: 80-120 IOPS       ★☆☆☆☆
  随机写IOPS: 80-120 IOPS       ★☆☆☆☆
  应用场景:   冷数据存储、归档

10000转 企业级HDD:
  顺序写入:   120-200 MB/s      ★★☆☆☆
  顺序读取:   120-220 MB/s      ★★☆☆☆
  随机读IOPS: 120-180 IOPS      ★★☆☆☆
  随机写IOPS: 120-180 IOPS      ★★☆☆☆
  应用场景:   企业存储

15000转 高性能HDD:
  顺序写入:   150-250 MB/s      ★★☆☆☆
  顺序读取:   150-280 MB/s      ★★☆☆☆
  随机读IOPS: 180-250 IOPS      ★★☆☆☆
  随机写IOPS: 180-250 IOPS      ★★☆☆☆
  应用场景:   企业数据库

【SATA SSD固态硬盘】
----------------------------------------

SATA SSD (SATA3 6Gbps):
  顺序写入:   350-550 MB/s      ★★★☆☆
  顺序读取:   400-560 MB/s      ★★★☆☆
  随机读IOPS: 50K-95K IOPS      ★★★☆☆
  随机写IOPS: 40K-90K IOPS      ★★★☆☆
  应用场景:   桌面、入门级服务器

【NVMe SSD】
----------------------------------------

NVMe PCIe 3.0 x2:
  顺序写入:   800-1500 MB/s     ★★★☆☆
  顺序读取:   1200-1800 MB/s    ★★★☆☆
  随机读IOPS: 150K-300K IOPS    ★★★★☆
  随机写IOPS: 120K-280K IOPS    ★★★★☆
  应用场景:   主流服务器

NVMe PCIe 3.0 x4:
  顺序写入:   1500-3200 MB/s    ★★★★☆
  顺序读取:   2000-3500 MB/s    ★★★★☆
  随机读IOPS: 300K-600K IOPS    ★★★★☆
  随机写IOPS: 250K-550K IOPS    ★★★★☆
  应用场景:   高性能服务器

NVMe PCIe 4.0 x4:
  顺序写入:   3000-5000 MB/s    ★★★★★
  顺序读取:   5000-7000 MB/s    ★★★★★
  随机读IOPS: 500K-1000K IOPS   ★★★★★
  随机写IOPS: 400K-900K IOPS    ★★★★★
  应用场景:   顶级服务器、数据库

NVMe PCIe 5.0 x4:
  顺序写入:   8000-12000 MB/s   ★★★★★
  顺序读取:   10000-14000 MB/s  ★★★★★
  随机读IOPS: 1000K-2000K IOPS  ★★★★★
  随机写IOPS: 800K-1800K IOPS   ★★★★★
  应用场景:   极致性能场景

【RAID阵列】
----------------------------------------

RAID 0 (2盘条带):
  理论性能: 单盘 × 2
  实际性能: 单盘 × 1.7-1.9
  可靠性:   无冗余

RAID 1 (2盘镜像):
  写入性能: 单盘 × 1.0
  读取性能: 单盘 × 1.5-2.0
  可靠性:   1盘冗余

RAID 5 (3盘+校验):
  写入性能: 单盘 × 0.7-1.2 (校验开销)
  读取性能: 单盘 × 2.5-2.8
  可靠性:   1盘冗余

RAID 10 (4盘镜像条带):
  写入性能: 单盘 × 1.8-1.9
  读取性能: 单盘 × 3.5-3.8
  可靠性:   每组1盘冗余

STORAGE

    echo ""

    # ========== 实际测试结果分析 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "4. 实际测试结果分析"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 分析基础吞吐量测试
    if [[ -f "$RESULTS_DIR/basic_throughput.txt" ]]; then
        echo "【基础吞吐量测试结果】"
        echo "----------------------------------------"
        echo ""
        cat "$RESULTS_DIR/basic_throughput.txt"
        echo ""

        # 分析性能趋势
        echo "性能趋势分析:"
        echo ""

        # 提取最大和最小文件大小的性能
        first_line=$(grep -E "^  [0-9]+[kmg]" "$RESULTS_DIR/basic_throughput.txt" | head -1)
        last_line=$(grep -E "^  [0-9]+[kmg]" "$RESULTS_DIR/basic_throughput.txt" | tail -1)

        if [[ -n "$first_line" ]] && [[ -n "$last_line" ]]; then
            first_write=$(echo "$first_line" | awk '{print $3}')
            last_write=$(echo "$last_line" | awk '{print $3}')

            if [[ -n "$first_write" ]] && [[ -n "$last_write" ]]; then
                echo "  最小文件写入: $first_write KB/s"
                echo "  最大文件写入: $last_write KB/s"

                if (( $(echo "$last_write > $first_write * 1.5" | bc -l 2>/dev/null || echo 0) )); then
                    echo "  ✓ 性能随文件大小增长明显"
                    echo "    → 小文件有元数据开销"
                    echo "    → 大文件更能体现真实带宽"
                elif (( $(echo "$last_write < $first_write * 0.7" | bc -l 2>/dev/null || echo 0) )); then
                    echo "  ⚠ 大文件性能下降"
                    echo "    → 可能是缓存耗尽"
                    echo "    → 或写入缓冲区问题"
                else
                    echo "  ✓ 性能稳定，不受文件大小影响"
                fi
                echo ""
            fi
        fi
    fi

    # 分析记录大小影响
    if [[ -f "$RESULTS_DIR/record_size.txt" ]]; then
        echo "【记录大小影响分析】"
        echo "----------------------------------------"
        echo ""
        cat "$RESULTS_DIR/record_size.txt"
        echo ""

        echo "关键发现:"
        echo ""

        # 查找性能峰值
        peak_recsize=$(grep -E "^[0-9]+[kmg]?" "$RESULTS_DIR/record_size.txt" | \
            awk '{print $1, $2}' | sort -k2 -nr | head -1 | awk '{print $1}')

        if [[ -n "$peak_recsize" ]]; then
            echo "  最佳记录大小: $peak_recsize"
            echo "  → 这是该存储设备的最优块大小"
            echo "  → 应用程序应使用此大小进行I/O"
            echo ""
        fi

        # 分析小块性能
        small_perf=$(grep -E "^512" "$RESULTS_DIR/record_size.txt" | awk '{print $2}')
        large_perf=$(grep -E "^1m" "$RESULTS_DIR/record_size.txt" | awk '{print $2}')

        if [[ -n "$small_perf" ]] && [[ -n "$large_perf" ]]; then
            echo "  512B vs 1MB 性能差异:"
            echo "    512B:  $small_perf KB/s"
            echo "    1MB:   $large_perf KB/s"

            if (( $(echo "$large_perf > $small_perf * 5" | bc -l 2>/dev/null || echo 0) )); then
                echo "    → 小块I/O性能损失严重"
                echo "    → 避免使用小记录大小"
            fi
            echo ""
        fi
    fi

    # 分析多线程测试
    if [[ -f "$RESULTS_DIR/multithread.txt" ]]; then
        echo "【多线程并发分析】"
        echo "----------------------------------------"
        echo ""
        cat "$RESULTS_DIR/multithread.txt"
        echo ""

        echo "并行扩展性分析:"
        echo ""

        # 提取1线程和最大线程的性能
        thread_1=$(grep -E "^1 " "$RESULTS_DIR/multithread.txt" | awk '{print $2}')
        max_thread_line=$(grep -E "^[0-9]+ " "$RESULTS_DIR/multithread.txt" | tail -1)
        max_threads=$(echo "$max_thread_line" | awk '{print $1}')
        max_perf=$(echo "$max_thread_line" | awk '{print $2}')

        if [[ -n "$thread_1" ]] && [[ -n "$max_perf" ]] && [[ -n "$max_threads" ]]; then
            speedup=$(echo "scale=2; $max_perf / $thread_1" | bc 2>/dev/null || echo "N/A")
            efficiency=$(echo "scale=1; ($speedup / $max_threads) * 100" | bc 2>/dev/null || echo "N/A")

            echo "  基准(1线程):   $thread_1 KB/s"
            echo "  最大($max_threads线程): $max_perf KB/s"
            echo "  加速比:        ${speedup}x"
            echo "  并行效率:      ${efficiency}%"
            echo ""

            if [[ "$efficiency" != "N/A" ]]; then
                if (( $(echo "$efficiency > 80" | bc -l 2>/dev/null || echo 0) )); then
                    echo "  ✓ 优秀的并行扩展性"
                    echo "    → 存储子系统可充分利用并发"
                elif (( $(echo "$efficiency > 60" | bc -l 2>/dev/null || echo 0) )); then
                    echo "  ✓ 良好的并行扩展性"
                elif (( $(echo "$efficiency > 40" | bc -l 2>/dev/null || echo 0) )); then
                    echo "  ⚠ 一般的并行扩展性"
                    echo "    → 可能存在锁竞争或带宽瓶颈"
                else
                    echo "  ⚠ 较差的并行扩展性"
                    echo "    → 存在严重瓶颈"
                    echo "    → 检查: 存储带宽、文件系统锁、RAID配置"
                fi
                echo ""
            fi
        fi
    fi

    # 分析随机I/O
    if [[ -f "$RESULTS_DIR/random_io.txt" ]]; then
        echo "【随机I/O性能分析（数据库场景）】"
        echo "----------------------------------------"
        echo ""
        cat "$RESULTS_DIR/random_io.txt"
        echo ""

        echo "数据库性能预测:"
        echo ""

        # 提取IOPS
        rand_read_iops=$(grep "随机读IOPS:" "$RESULTS_DIR/random_io.txt" | awk '{print $2}')
        rand_write_iops=$(grep "随机写IOPS:" "$RESULTS_DIR/random_io.txt" | awk '{print $2}')

        if [[ -n "$rand_read_iops" ]] && [[ -n "$rand_write_iops" ]]; then
            echo "  随机读IOPS:  $rand_read_iops"
            echo "  随机写IOPS:  $rand_write_iops"
            echo ""

            # 数据库性能评估
            if (( rand_read_iops > 100000 )); then
                echo "  数据库性能评级: ★★★★★ 卓越"
                echo "    适用: 高负载OLTP、内存数据库"
            elif (( rand_read_iops > 50000 )); then
                echo "  数据库性能评级: ★★★★☆ 优秀"
                echo "    适用: 中高负载OLTP、在线分析"
            elif (( rand_read_iops > 10000 )); then
                echo "  数据库性能评级: ★★★☆☆ 良好"
                echo "    适用: 中等负载OLTP、Web应用"
            elif (( rand_read_iops > 1000 )); then
                echo "  数据库性能评级: ★★☆☆☆ 一般"
                echo "    适用: 低负载OLTP、开发测试"
            else
                echo "  数据库性能评级: ★☆☆☆☆ 入门级"
                echo "    适用: 归档、报表、离线分析"
            fi
            echo ""

            # 存储类型判断
            if (( rand_read_iops > 300000 )); then
                echo "  存储类型判断: NVMe PCIe 4.0 或更高"
            elif (( rand_read_iops > 100000 )); then
                echo "  存储类型判断: NVMe PCIe 3.0 x4"
            elif (( rand_read_iops > 50000 )); then
                echo "  存储类型判断: NVMe PCIe 3.0 x2 或 高端SATA SSD"
            elif (( rand_read_iops > 10000 )); then
                echo "  存储类型判断: SATA SSD"
            elif (( rand_read_iops > 200 )); then
                echo "  存储类型判断: 高性能HDD或RAID"
            else
                echo "  存储类型判断: 普通HDD"
            fi
            echo ""
        fi
    fi

    # ========== 性能瓶颈识别 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "5. 性能瓶颈识别"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cat <<'BOTTLENECK'
【症状1: Write远低于硬件规格】
----------------------------------------

预期: NVMe PCIe 3.0应达到 1500-3200 MB/s
实际: 仅500 MB/s

可能原因:
  1. 文件系统配置不当
     诊断: mount | grep -E "noatime|barrier"
     解决: mount -o remount,noatime,nodiratime,nobarrier /

  2. I/O调度器不适合SSD
     诊断: cat /sys/block/nvme0n1/queue/scheduler
     解决: echo none > /sys/block/nvme0n1/queue/scheduler

  3. 写缓存未启用
     诊断: hdparm -W /dev/nvme0n1
     解决: hdparm -W1 /dev/nvme0n1

  4. RAID配置问题
     诊断: cat /proc/mdstat
     解决: 检查RAID级别和条带大小

【症状2: Reread性能异常低】
----------------------------------------

预期: Reread应 >> Read (缓存命中)
实际: Reread ≈ Read

可能原因:
  1. 测试文件大于内存
     → IOzone使用的文件太大
     → 减小测试文件或增加内存

  2. 缓存被清空
     → 测试间隔时间太长
     → 系统内存压力大

  3. Direct I/O模式
     → 使用了-I参数绕过缓存
     → 检查测试参数

【症状3: Random Read/Write性能极差】
----------------------------------------

预期: SSD随机IOPS > 50K
实际: < 5K IOPS

可能原因:
  1. 使用HDD而非SSD
     诊断: lsblk -d -o name,rota
     诊断: rota=1表示HDD

  2. SSD已严重磨损
     诊断: smartctl -a /dev/nvme0n1
     诊断: 检查Percentage Used

  3. 未对齐分区
     诊断: parted /dev/nvme0n1 align-check optimal 1
     解决: 重新分区对齐

  4. 文件系统碎片
     诊断: e4defrag -c /
     解决: e4defrag /

【症状4: 多线程扩展性差】
----------------------------------------

预期: 16线程应有5-10x加速
实际: 仅2x加速

可能原因:
  1. 存储带宽饱和
     → 单盘已达上限
     → 考虑RAID 0或多盘

  2. 文件系统锁竞争
     → 单个目录并发限制
     → 使用多个测试目录

  3. 队列深度不足
     诊断: cat /sys/block/nvme0n1/queue/nr_requests
     解决: echo 1024 > /sys/block/nvme0n1/queue/nr_requests

BOTTLENECK

    echo ""

    # ========== 优化建议 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "6. 性能优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cat <<'OPTIMIZATION'
【文件系统优化】
----------------------------------------

1. ext4优化
   mount -o noatime,nodiratime,data=writeback,barrier=0,commit=60 /dev/nvme0n1p1 /mnt

   关键选项:
     noatime: 不更新访问时间（减少写入）
     data=writeback: 异步写入（性能优先）
     barrier=0: 禁用写屏障（需电池保护）
     commit=60: 延长提交间隔

2. xfs优化
   mount -o noatime,nodiratime,logbufs=8,logbsize=256k,largeio,swalloc /dev/nvme0n1p1 /mnt

   关键选项:
     logbufs=8: 增加日志缓冲区
     logbsize=256k: 增大日志缓冲大小
     largeio: 大I/O优化
     swalloc: 条带对齐

3. btrfs优化
   mount -o noatime,nodiratime,compress=lzo,ssd,space_cache=v2 /dev/nvme0n1p1 /mnt

   关键选项:
     compress=lzo: 轻量级压缩
     ssd: SSD优化
     space_cache=v2: 改进的空间缓存

【I/O调度器优化】
----------------------------------------

1. NVMe设备
   echo none > /sys/block/nvme0n1/queue/scheduler
   # NVMe自带硬件队列，不需要内核调度

2. SATA SSD
   echo mq-deadline > /sys/block/sda/queue/scheduler
   # 低延迟，适合SSD

3. HDD
   echo bfq > /sys/block/sda/queue/scheduler
   # 公平调度，适合交互式负载

【内核参数优化】
----------------------------------------

1. 脏页设置（写入密集型）
   sysctl -w vm.dirty_ratio=15
   sysctl -w vm.dirty_background_ratio=5
   sysctl -w vm.dirty_writeback_centisecs=100
   sysctl -w vm.dirty_expire_centisecs=200

   说明:
     dirty_ratio: 脏页达到15%时阻塞写入
     dirty_background_ratio: 5%时后台回写
     减小值: 更频繁刷盘，延迟更低
     增大值: 更多缓存，吞吐更高

2. 读优化
   blockdev --setra 8192 /dev/nvme0n1
   # 增加预读，提升顺序读性能

3. 队列深度
   echo 1024 > /sys/block/nvme0n1/queue/nr_requests
   # 增加队列深度，提升并发性能

【应用层优化】
----------------------------------------

1. 数据库优化
   # MySQL InnoDB
   innodb_flush_log_at_trx_commit = 2  # 性能优先
   innodb_flush_method = O_DIRECT      # 绕过系统缓存
   innodb_io_capacity = 2000           # 匹配IOPS能力

   # PostgreSQL
   synchronous_commit = off            # 异步提交
   wal_buffers = 16MB                  # 增大WAL缓冲
   checkpoint_timeout = 15min          # 延长检查点间隔

2. 使用正确的块大小
   # 数据库: 通常8KB或16KB
   # 大文件传输: 1MB或更大
   # 小文件: 4KB

3. 使用Direct I/O（数据库场景）
   # 绕过页缓存，避免双重缓存
   open(file, O_DIRECT | O_SYNC)

【RAID优化】
----------------------------------------

1. RAID 0（性能优先）
   mdadm --create /dev/md0 --level=0 --raid-devices=2 \
         --chunk=512 /dev/nvme0n1 /dev/nvme1n1

   关键参数:
     chunk=512: 条带大小512KB（匹配工作负载）

2. RAID 10（性能+可靠性）
   mdadm --create /dev/md0 --level=10 --raid-devices=4 \
         --chunk=256 /dev/nvme[0-3]n1

3. 条带大小选择
   小文件随机I/O: 64-128 KB
   大文件顺序I/O: 512 KB - 1 MB
   数据库: 256-512 KB

OPTIMIZATION

    echo ""

    # ========== 不同应用场景建议 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "7. 不同应用场景优化建议"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cat <<'SCENARIOS'
【数据库服务器】
----------------------------------------

关键指标:
  ✓ Random Read IOPS > 50K
  ✓ Random Write IOPS > 40K
  ✓ 延迟 < 1ms

优化重点:
  1. 存储: NVMe SSD + RAID 10
  2. 文件系统: xfs或ext4，noatime，barrier=0
  3. I/O调度器: none（NVMe）或mq-deadline（SATA）
  4. 应用配置: O_DIRECT，异步提交
  5. 记录大小: 8KB或16KB

【Web服务器】
----------------------------------------

关键指标:
  ✓ Sequential Read > 1 GB/s
  ✓ 小文件读取性能
  ✓ 缓存命中率

优化重点:
  1. 存储: SATA SSD即可
  2. 文件系统: ext4，noatime
  3. 内存: 增大页缓存
  4. 应用: 启用sendfile，gzip压缩
  5. CDN: 静态资源使用CDN

【视频流媒体】
----------------------------------------

关键指标:
  ✓ Sequential Read > 500 MB/s
  ✓ 多线程并发读取
  ✓ 稳定低延迟

优化重点:
  1. 存储: 大容量HDD RAID 5/6 或 SATA SSD
  2. 文件系统: xfs，largeio
  3. 块大小: 1MB或更大
  4. 预读: 增大readahead
  5. 网络: 10GbE或更高

【虚拟化平台】
----------------------------------------

关键指标:
  ✓ Random IOPS > 100K（整体）
  ✓ 低延迟 < 5ms
  ✓ QoS保证

优化重点:
  1. 存储: NVMe SSD + RAID 10
  2. 虚拟化存储: LVM thin provisioning 或 Ceph
  3. I/O隔离: blkio cgroup
  4. 缓存: 主机端缓存 + 虚拟机缓存
  5. 快照: 使用增量快照

【大数据/分析】
----------------------------------------

关键指标:
  ✓ Sequential Read > 2 GB/s
  ✓ 并发吞吐量
  ✓ 总容量

优化重点:
  1. 存储: 多盘RAID 0或JBOD
  2. 文件系统: xfs或ext4，大块大小
  3. 块大小: 1MB - 4MB
  4. 并行: 多线程读取
  5. 压缩: 使用列式存储+压缩

【日志/监控】
----------------------------------------

关键指标:
  ✓ Sequential Write > 500 MB/s
  ✓ 写入稳定性
  ✓ 磁盘容量

优化重点:
  1. 存储: SATA SSD 或 HDD RAID 5
  2. 文件系统: ext4或xfs，data=writeback
  3. 日志轮转: 定期清理
  4. 缓冲: 应用层批量写入
  5. 压缩: 旧日志压缩存储

SCENARIOS

    echo ""

    # ========== 结果验证 ==========
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "8. 结果合理性验证"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cat <<'VALIDATION'
【检查点1: Rewrite vs Write】
----------------------------------------

合理范围: Rewrite = 110-130% of Write

原因:
  - Rewrite时元数据已存在
  - 可能复用磁盘块
  - 减少分配开销

异常情况:
  ❌ Rewrite < Write
     → 不正常，检查测试过程
  ❌ Rewrite > 200% of Write
     → 可能文件被缓存

【检查点2: Reread vs Read】
----------------------------------------

合理范围: Reread = 200-500% of Read

原因:
  - Reread从页缓存读取
  - 受内存带宽限制而非磁盘

异常情况:
  ❌ Reread ≈ Read
     → 缓存未命中，文件太大或内存不足
  ❌ Reread > 10x Read
     → 可能是小文件测试，结果不准确

【检查点3: Random vs Sequential】
----------------------------------------

HDD合理比例: Random = 1-5% of Sequential
SSD合理比例: Random = 40-80% of Sequential
NVMe合理比例: Random = 60-90% of Sequential

异常情况:
  ❌ HDD Random > 10% Sequential
     → 可能是RAID或SSD误识别为HDD
  ❌ SSD Random < 20% Sequential
     → SSD性能退化或配置问题

【检查点4: 多线程扩展性】
----------------------------------------

合理扩展:
  2线程: 1.5-1.9x
  4线程: 2.5-3.5x
  8线程: 4.0-6.0x
  16线程: 6.0-10.0x

异常情况:
  ❌ 2线程 < 1.3x
     → 存在严重瓶颈
  ❌ 8线程 > 7.5x
     → 可能单线程测试有问题

【检查点5: IOPS一致性】
----------------------------------------

计算验证:
  IOPS = Throughput(KB/s) / Record_Size(KB)

示例:
  Throughput: 400,000 KB/s
  Record Size: 8 KB
  IOPS = 400,000 / 8 = 50,000 IOPS

异常情况:
  ❌ 计算IOPS与声称IOPS差异超过20%
     → 检查测试参数和单位

VALIDATION

    echo ""

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "分析完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

} | tee "$ANALYSIS_FILE"

echo ""
echo "✓ 详细分析完成"
echo ""
echo "查看完整分析: cat $ANALYSIS_FILE"
echo ""
