# 测试结果解析文档

本目录包含所有测试类型的详细结果解析文档，帮助你理解测试输出、分析性能数据和诊断问题。

---

## 📚 文档列表

### [网络性能测试结果解析](NETWORK_RESULTS.md)
**适用于**: `scripts/network/network-test.sh`

**内容涵盖**:
- Ping 跟踪结果详解
- 网络事件字段说明
- 数据包流程时间线分析
- 网络接口信息解读
- Socket 统计分析
- 性能基准对比
- 常见问题诊断

**关键指标**:
- 发送队列延迟
- 网络往返时间 (RTT)
- 丢包率和错误率
- CPU 负载分布

---

### [进程调度测试结果解析](SCHED_RESULTS.md)
**适用于**: `scripts/sched/sched-test.sh`

**内容涵盖**:
- 调度延迟报告详解
- 调度时间线分析
- CPU 调度映射解读
- 空闲 vs 高负载对比
- 上下文切换分析
- 性能基准标准
- 优化建议

**关键指标**:
- 平均调度延迟
- 最大调度延迟
- 上下文切换频率
- CPU 利用率

---

### [块设备I/O测试结果解析](BLOCK_RESULTS.md)
**适用于**: `scripts/block/block-test.sh`

**内容涵盖**:
- 缓存写入 vs Direct I/O
- 块事件详细解析
- I/O 延迟分段分析
- 页缓存行为理解
- 性能基准对比
- 磁盘类型性能标准
- I/O 优化建议

**关键指标**:
- 吞吐量 (MB/s)
- IOPS (每秒I/O操作数)
- I/O 延迟
- 块事件计数

---

### [TCP协议栈测试结果解析](TCP_RESULTS.md)
**适用于**: `scripts/tcp/tcp-test.sh`

**内容涵盖**:
- Packetdrill 语法详解
- TCP 三次握手分析
- 数据传输过程
- 序列号追踪
- 常见错误解决
- 测试场景示例
- 调试技巧

**关键指标**:
- TCP 选项正确性
- 序列号/确认号
- 窗口大小
- 协议时序

---

## 🎯 快速导航

### 按测试类型查找

| 测试类型 | 解析文档 | 测试脚本 |
|---------|---------|---------|
| 网络性能 | [NETWORK_RESULTS.md](NETWORK_RESULTS.md) | `scripts/network/network-test.sh` |
| 进程调度 | [SCHED_RESULTS.md](SCHED_RESULTS.md) | `scripts/sched/sched-test.sh` |
| 块设备I/O | [BLOCK_RESULTS.md](BLOCK_RESULTS.md) | `scripts/block/block-test.sh` |
| TCP协议栈 | [TCP_RESULTS.md](TCP_RESULTS.md) | `scripts/tcp/tcp-test.sh` |

### 按问题类型查找

| 问题类型 | 推荐阅读 |
|---------|---------|
| 网络延迟高 | [网络结果解析 - 性能基准](NETWORK_RESULTS.md#7-性能基准和分析) |
| 进程响应慢 | [调度结果解析 - 调度延迟](SCHED_RESULTS.md#1-调度延迟报告解析-perf-sched-latency) |
| 磁盘速度慢 | [块设备结果解析 - 性能基准](BLOCK_RESULTS.md#5-性能基准和标准) |
| TCP连接失败 | [TCP结果解析 - 常见错误](TCP_RESULTS.md#2-packetdrill-测试失败示例) |

---

## 📊 结果文件命名规范

### 网络测试结果
```
results/network/
├── ping_trace_YYYYMMDD_HHMMSS.txt      # Ping 跟踪
├── ping_events_YYYYMMDD_HHMMSS.txt     # 网络事件
├── network_info_YYYYMMDD_HHMMSS.txt    # 接口信息
└── report_YYYYMMDD_HHMMSS.txt          # 测试报告
```

### 调度测试结果
```
results/sched/
├── sched_idle_latency_YYYYMMDD_HHMMSS.txt    # 空闲延迟
├── sched_stress_latency_YYYYMMDD_HHMMSS.txt  # 高负载延迟
├── sched_timehist_YYYYMMDD_HHMMSS.txt        # 时间线
├── sched_map_YYYYMMDD_HHMMSS.txt             # CPU映射
└── report_YYYYMMDD_HHMMSS.txt                # 测试报告
```

### 块设备测试结果
```
results/block/
├── block_cached_YYYYMMDD_HHMMSS.txt          # 缓存写入
├── block_direct_write_YYYYMMDD_HHMMSS.txt    # Direct I/O写
├── block_direct_read_YYYYMMDD_HHMMSS.txt     # Direct I/O读
├── block_fsync_YYYYMMDD_HHMMSS.txt           # fsync同步
├── block_events_YYYYMMDD_HHMMSS.txt          # 块事件
└── report_YYYYMMDD_HHMMSS.txt                # 测试报告
```

### TCP测试结果
```
results/tcp/
├── basic_tcp_YYYYMMDD_HHMMSS.txt        # 基本TCP测试
├── window_scaling_YYYYMMDD_HHMMSS.txt   # 窗口扩展测试
└── report_YYYYMMDD_HHMMSS.txt           # 测试报告
```

---

## 🔍 如何使用解析文档

### 第1步：运行测试
```bash
# 运行特定测试
sudo ./scripts/network/network-test.sh

# 或运行所有测试
sudo ./scripts/run-all.sh
```

### 第2步：查看结果
```bash
# 查看最新的测试报告
ls -lt results/network/report_*.txt | head -1 | xargs cat
```

### 第3步：对照解析文档
```bash
# 打开对应的解析文档
cat docs/results/NETWORK_RESULTS.md
```

### 第4步：深入分析
根据文档中的指引：
1. 理解每个指标的含义
2. 对比性能基准
3. 诊断发现的问题
4. 应用优化建议

---

## 📈 性能基准速查表

### 网络延迟

| 场景 | 优秀 | 良好 | 可接受 | 需优化 |
|------|------|------|--------|--------|
| 本地回环 | < 0.05ms | < 0.1ms | < 0.2ms | > 0.5ms |
| 局域网 | < 0.5ms | < 1ms | < 2ms | > 5ms |
| 跨数据中心 | < 10ms | < 50ms | < 100ms | > 200ms |

### 调度延迟

| 系统类型 | 平均延迟 | 最大延迟 |
|---------|---------|---------|
| 桌面系统 | < 5ms | < 20ms |
| 服务器 | < 10ms | < 50ms |
| 实时系统 | < 100μs | < 1ms |

### 磁盘性能

| 设备类型 | 顺序读 | 顺序写 | 随机读4K | 随机写4K |
|---------|--------|--------|---------|---------|
| SATA SSD | > 500MB/s | > 500MB/s | > 80K IOPS | > 70K IOPS |
| NVMe SSD | > 3GB/s | > 2.5GB/s | > 500K IOPS | > 400K IOPS |
| HDD | > 150MB/s | > 150MB/s | > 150 IOPS | > 120 IOPS |

---

## ⚙️ 常见问题

### Q: 结果文件太多，如何管理？

**A**: 定期清理旧结果
```bash
# 只保留最近7天的结果
find results/ -name "*.txt" -mtime +7 -delete

# 或归档旧结果
tar czf results_archive_$(date +%Y%m%d).tar.gz results/
```

### Q: 如何对比两次测试结果？

**A**: 使用 diff 或专门的对比工具
```bash
# 简单对比
diff -u results/network/report_20260418_100000.txt \
        results/network/report_20260418_110000.txt

# 提取关键指标对比
grep "速度\|延迟\|IOPS" results/block/report_*.txt
```

### Q: 测试结果异常，如何诊断？

**A**: 按以下步骤：
1. 查看对应的解析文档中的"常见问题诊断"章节
2. 检查系统日志: `dmesg`, `journalctl`
3. 验证系统配置
4. 在空闲系统上重新测试

---

## 🛠️ 进阶技巧

### 自动化分析脚本

```bash
#!/bin/bash
# 提取关键性能指标

REPORT=$1

echo "=== 性能摘要 ==="

# 网络测试
if [[ $REPORT == *"network"* ]]; then
    grep "time=" $REPORT | awk '{print "RTT: " $7}'
    grep "发送事件" $REPORT
fi

# 调度测试
if [[ $REPORT == *"sched"* ]]; then
    grep "Avg delay" $REPORT | head -5
    grep "CPU利用率" $REPORT
fi

# 块设备测试
if [[ $REPORT == *"block"* ]]; then
    grep "MB/s\|GB/s" $REPORT
    grep "IOPS" $REPORT
fi
```

### 性能趋势分析

```bash
# 收集历史数据
for report in results/network/report_*.txt; do
    date=$(basename $report | cut -d_ -f2-3)
    rtt=$(grep "time=" $report | awk '{print $7}' | cut -d= -f2)
    echo "$date,$rtt"
done > network_trend.csv

# 使用gnuplot等工具绘图
```

---

## 📝 贡献

如果你发现文档中的错误或有改进建议，欢迎：
1. 提交 Issue
2. 发送 Pull Request
3. 联系维护者

---

## 📚 相关文档

- [项目主文档](../../README.md)
- [详细测试指南](../DETAILED_GUIDE.md)
- [快速参考](../QUICK_REFERENCE.md)
- [项目结构说明](../PROJECT_STRUCTURE.md)

---

**最后更新**: 2026-04-18
**文档版本**: 1.0
