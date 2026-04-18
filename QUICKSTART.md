# 快速开始指南

## 目录结构

```
linux-testing/
├── README.md              # 详细文档
├── QUICKSTART.md         # 本文件（快速开始）
├── scripts/              # 测试脚本
│   ├── run-all-tests.sh  # 运行所有测试
│   ├── network-test.sh   # 网络性能测试
│   ├── sched-test.sh     # 调度性能测试
│   └── block-test.sh     # 块设备I/O测试
├── tests/                # 测试用例
│   ├── packetdrill/      # Packetdrill TCP 测试
│   ├── network/          # 网络测试用例
│   ├── sched/            # 调度测试用例
│   └── block/            # 块设备测试用例
└── results/              # 测试结果（自动生成）
    ├── network/
    ├── sched/
    └── block/
```

## 快速运行

### 方法1: 运行所有测试（推荐）

```bash
cd linux-testing
sudo ./scripts/run-all-tests.sh
```

所有测试结果会保存在 `results/` 目录下。

### 方法2: 单独运行某个测试

```bash
# 网络性能测试
sudo ./scripts/network-test.sh

# 进程调度测试
sudo ./scripts/sched-test.sh

# 块设备I/O测试
sudo ./scripts/block-test.sh
```

## 常见命令速查

### 网络测试

```bash
# 跟踪 ping 包
perf trace -e 'net:*' ping -c 1 google.com

# 记录详细网络事件
perf record -e 'net:*' -a ping -c 1 google.com
perf script
```

### 调度测试

```bash
# 记录调度事件
perf sched record -a sleep 10

# 查看调度延迟
perf sched latency

# 查看时间线
perf sched timehist

# 查看 CPU 映射
perf sched map
```

### 块设备测试

```bash
# 缓存写入（快速，无磁盘I/O）
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100

# Direct I/O（真实磁盘速度）
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 oflag=direct

# 同步写入（写入+刷盘）
perf stat -e 'block:*' dd if=/dev/zero of=test bs=1M count=100 conv=fsync
```

### Packetdrill TCP 测试

```bash
# 运行基本 TCP 测试
cd tests/packetdrill
packetdrill basic_tcp.pkt

# 详细输出
packetdrill --verbose basic_tcp.pkt
```

## 系统要求

### 必需工具

- `perf` - 性能分析工具
  ```bash
  # RHEL/CentOS
  yum install perf

  # Debian/Ubuntu
  apt install linux-tools-$(uname -r)
  ```

### 可选工具

- `stress-ng` - CPU 压力测试
  ```bash
  # RHEL/CentOS
  yum install stress-ng

  # Debian/Ubuntu
  apt install stress-ng
  ```

- `packetdrill` - TCP 协议栈测试
  ```bash
  git clone https://github.com/google/packetdrill.git
  cd packetdrill/gtests/net/packetdrill
  ./configure && make
  ```

## 权限说明

某些命令需要 root 权限：
- `perf` 跟踪系统级事件（使用 `-a` 参数）
- 清空页缓存 (`echo 3 > /proc/sys/vm/drop_caches`)
- Packetdrill 测试（需要创建网络接口）

建议使用 `sudo` 运行测试脚本。

## 故障排除

### 问题1: perf 命令未找到

```bash
# 检查内核版本
uname -r

# 安装对应版本的 perf
yum install perf  # 或 apt install linux-tools-$(uname -r)
```

### 问题2: 权限不足

```bash
# 临时允许非 root 用户使用 perf
sudo sysctl -w kernel.perf_event_paranoid=-1

# 或使用 sudo 运行
sudo perf ...
```

### 问题3: 测试结果全是 0

这通常是正常的：
- 网络测试：系统空闲，延迟为 0
- 块设备测试：数据在页缓存中，没有真实磁盘 I/O
- 解决：使用 `oflag=direct` 或创建负载（`stress-ng`）

### 问题4: packetdrill 测试失败

常见原因：
- TCP 选项顺序不匹配 → 使用实际内核返回的顺序
- 窗口大小不匹配 → 使用实际的窗口值
- 端口被占用 → 等待一会儿或修改测试脚本

## 查看结果

### 实时查看

测试运行时会在终端显示进度和关键信息。

### 查看详细报告

```bash
# 查看最新的汇总报告
cat results/summary_*.txt | tail -100

# 查看网络测试报告
ls -lt results/network/report_*.txt | head -1 | xargs cat

# 查看调度测试报告
ls -lt results/sched/report_*.txt | head -1 | xargs cat

# 查看块设备测试报告
ls -lt results/block/report_*.txt | head -1 | xargs cat
```

### 查看原始数据

所有原始数据文件保存在对应的 `results/` 子目录中，包括：
- perf 记录文件 (`.data`)
- 事件脚本输出 (`.txt`)
- 性能统计 (`.txt`)

## 清理测试数据

```bash
# 清理所有测试结果
rm -rf results/*

# 只清理 perf 数据文件（较大）
find results/ -name "*.data" -delete

# 清理测试生成的临时文件
rm -f test_io_*.dat test
```

## 下一步

- 阅读 [README.md](README.md) 了解详细的测试原理和参数说明
- 查看 `tests/` 目录下的示例测试用例
- 根据需要修改脚本参数（测试时长、负载大小等）
- 将测试集成到 CI/CD 流程中

## 技术支持

如有问题或建议，请查看：
- [Perf Wiki](https://perf.wiki.kernel.org/)
- [Brendan Gregg's Performance Tools](http://www.brendangregg.com/perf.html)
- [Packetdrill GitHub](https://github.com/google/packetdrill)

---

**祝测试愉快！** 🚀
