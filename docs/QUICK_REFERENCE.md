# 快速参考卡片

## 一键命令

```bash
# 1. 安装所有工具
sudo ./setup/install-tools.sh

# 2. 运行所有测试
sudo ./scripts/run-all.sh

# 3. 查看结果
cat results/summary_*.md
```

---

## 单独测试命令

### 网络性能
```bash
sudo ./scripts/network/network-test.sh
```

### 进程调度
```bash
sudo ./scripts/sched/sched-test.sh
```

### 块设备I/O
```bash
sudo ./scripts/block/block-test.sh
```

### TCP协议栈
```bash
sudo ./scripts/tcp/tcp-test.sh
```

---

## 常用 Perf 命令

### 网络跟踪
```bash
# 跟踪 ping 包
perf trace -e 'net:*' ping -c 1 google.com

# 记录详细事件
perf record -e 'net:*' -a ping -c 1 google.com
perf script
```

### 调度分析
```bash
# 记录调度事件
perf sched record -a sleep 10

# 查看延迟
perf sched latency

# 查看时间线
perf sched timehist

# 查看CPU映射
perf sched map
```

### 块设备分析
```bash
# 缓存写入（快）
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100

# Direct I/O（真实磁盘）
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 oflag=direct

# 同步写入
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 conv=fsync
```

---

## Packetdrill TCP 测试

```bash
# 基本测试
packetdrill tests/tcp/basic_tcp.pkt

# 详细输出
packetdrill --verbose tests/tcp/basic_tcp.pkt

# 调试模式
packetdrill --debug tests/tcp/basic_tcp.pkt
```

---

## 系统信息命令

### CPU
```bash
lscpu                   # CPU架构
nproc                   # CPU核心数
cat /proc/cpuinfo       # 详细信息
```

### 内存
```bash
free -h                 # 内存使用
cat /proc/meminfo       # 详细信息
```

### 磁盘
```bash
lsblk                   # 块设备列表
df -h                   # 磁盘使用
iostat -x 1             # I/O统计
```

### 网络
```bash
ip link show            # 网络接口
ss -s                   # Socket统计
cat /proc/net/dev       # 网络统计
```

---

## 结果文件位置

```
results/
├── network/          # 网络测试结果
├── sched/            # 调度测试结果
├── block/            # 块设备测试结果
├── tcp/              # TCP测试结果
└── summary_*.md      # 汇总报告
```

---

## 清理命令

```bash
# 清理所有结果
rm -rf results/*

# 只清理大文件（perf数据）
find results/ -name "*.data" -delete

# 清理测试临时文件
rm -f test_io_*.dat test
```

---

## 故障排除

### 工具未找到
```bash
# 检查是否安装
command -v perf
command -v stress-ng

# 重新安装
sudo ./setup/install-tools.sh
```

### 权限问题
```bash
# 使用 sudo
sudo ./scripts/run-all.sh

# 配置 perf 权限
sudo sysctl -w kernel.perf_event_paranoid=-1
```

### 测试失败
```bash
# 查看错误日志
cat results/*/report_*.txt

# 单独运行失败的测试查看详细信息
sudo ./scripts/network/network-test.sh
```

---

## 性能标准

### 调度延迟
| 系统类型 | 目标延迟 |
|---------|---------|
| 桌面/服务器 | < 10ms |
| 低延迟 | < 1ms |
| 实时 | < 100μs |
| 硬实时 | < 10μs |

### 磁盘性能
| 设备类型 | 典型性能 |
|---------|---------|
| SSD 4K随机读 | 50-100K IOPS |
| SSD 顺序读 | 500MB/s - 3GB/s |
| HDD 顺序读 | 100-200 MB/s |
| 页缓存写入 | 2-10 GB/s |

### 网络延迟
| 类型 | 典型延迟 |
|------|---------|
| 本地回环 | < 0.1ms |
| 局域网 | < 1ms |
| 跨数据中心 | 5-50ms |
| 跨大洲 | 100-300ms |

---

## 快捷链接

- [项目主页](../README.md)
- [快速开始](../QUICKSTART.md)
- [项目结构](PROJECT_STRUCTURE.md)
- [详细指南](DETAILED_GUIDE.md)
- [工具说明](../tools/README.md)

---

**提示**: 将此页面加入书签，方便快速查阅！
