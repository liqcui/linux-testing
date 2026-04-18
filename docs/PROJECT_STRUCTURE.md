# 项目结构说明

## 目录组织

```
linux-testing/
│
├── setup/                    # 安装和配置
│   └── install-tools.sh      # 一键安装所有测试工具
│
├── tools/                    # 测试工具
│   ├── perf/                 # Perf 相关配置和脚本
│   ├── packetdrill/          # Packetdrill 源代码（自动下载）
│   ├── stress/               # Stress-ng 相关配置
│   ├── perf-helper.sh        # Perf 辅助脚本
│   ├── packetdrill-bin       # Packetdrill 软链接
│   └── README.md             # 工具使用说明
│
├── scripts/                  # 测试脚本（按类型分类）
│   ├── network/              # 网络性能测试脚本
│   │   └── network-test.sh
│   ├── sched/                # 进程调度测试脚本
│   │   └── sched-test.sh
│   ├── block/                # 块设备I/O测试脚本
│   │   └── block-test.sh
│   ├── tcp/                  # TCP协议栈测试脚本
│   │   └── tcp-test.sh
│   └── run-all.sh            # 主测试脚本（运行所有测试）
│
├── tests/                    # 测试用例（按类型分类）
│   ├── network/              # 网络测试用例
│   ├── sched/                # 调度测试用例
│   ├── block/                # 块设备测试用例
│   └── tcp/                  # TCP测试用例（packetdrill）
│       ├── basic_tcp.pkt     # 基本TCP三次握手
│       └── ...
│
├── results/                  # 测试结果（自动生成，已在.gitignore）
│   ├── network/              # 网络测试结果
│   ├── sched/                # 调度测试结果
│   ├── block/                # 块设备测试结果
│   ├── tcp/                  # TCP测试结果
│   └── summary_*.md          # 汇总报告
│
├── docs/                     # 文档
│   ├── PROJECT_STRUCTURE.md  # 本文件
│   ├── TESTING_GUIDE.md      # 测试指南
│   └── API_REFERENCE.md      # API参考（将来）
│
├── examples/                 # 示例和教程
│   ├── quick-start.sh        # 快速开始示例
│   └── ...
│
├── README.md                 # 项目主文档
├── QUICKSTART.md             # 快速开始指南
└── .gitignore                # Git忽略文件

```

## 设计原则

### 1. 按功能分类

所有文件按功能类型组织：
- **setup/** - 安装配置相关
- **tools/** - 工具本身
- **scripts/** - 测试脚本
- **tests/** - 测试用例
- **results/** - 测试结果
- **docs/** - 文档

### 2. 按测试类型分类

测试相关的目录（scripts/、tests/）进一步按测试类型分类：
- **network/** - 网络性能
- **sched/** - 进程调度
- **block/** - 块设备I/O
- **tcp/** - TCP协议栈

### 3. 独立性

每个测试类型的脚本都是独立的，可以单独运行：
```bash
./scripts/network/network-test.sh  # 只运行网络测试
./scripts/sched/sched-test.sh      # 只运行调度测试
./scripts/block/block-test.sh      # 只运行块设备测试
./scripts/tcp/tcp-test.sh          # 只运行TCP测试
```

### 4. 统一入口

提供统一的入口脚本：
```bash
./scripts/run-all.sh  # 运行所有测试
```

## 工作流程

### 第一次使用

```bash
# 1. 克隆项目
git clone <repo-url> linux-testing
cd linux-testing

# 2. 安装工具
sudo ./setup/install-tools.sh

# 3. 运行测试
sudo ./scripts/run-all.sh

# 4. 查看结果
cat results/summary_*.md
```

### 日常使用

```bash
# 运行特定测试
sudo ./scripts/network/network-test.sh

# 或运行所有测试
sudo ./scripts/run-all.sh

# 查看最新结果
ls -lt results/*/report_*.txt | head -5
```

## 文件命名规范

### 脚本文件
- 格式: `<功能>-test.sh`
- 示例: `network-test.sh`, `sched-test.sh`

### 测试用例
- Packetdrill: `<功能>.pkt`
- 示例: `basic_tcp.pkt`, `window_scaling.pkt`

### 结果文件
- 格式: `<类型>_<时间戳>.txt`
- 示例: `ping_trace_20260418_123456.txt`

### 报告文件
- 格式: `report_<时间戳>.txt`
- 汇总: `summary_<时间戳>.md`

## 扩展指南

### 添加新的测试类型

1. 创建目录结构：
   ```bash
   mkdir -p scripts/新类型
   mkdir -p tests/新类型
   ```

2. 创建测试脚本：
   ```bash
   cp scripts/network/network-test.sh scripts/新类型/新类型-test.sh
   # 编辑脚本...
   ```

3. 添加到主脚本：
   编辑 `scripts/run-all.sh`，添加新的测试调用

### 添加新的工具

1. 在 `setup/install-tools.sh` 中添加安装函数
2. 在 `tools/README.md` 中添加使用说明
3. 更新依赖检查

## 最佳实践

### 结果管理

- 结果文件自动带时间戳
- 定期清理旧结果：`rm -rf results/*`
- 重要结果可以备份到其他位置

### 版本控制

- `results/` 目录在 `.gitignore` 中
- 只提交代码和文档，不提交测试结果
- 测试用例应该提交到版本控制

### 权限管理

- 测试脚本需要 root 权限
- 使用 `sudo` 运行
- 配置 perf 权限允许普通用户使用（可选）

## 故障排除

### 工具未找到

```bash
# 检查工具是否安装
command -v perf
command -v stress-ng

# 重新安装
sudo ./setup/install-tools.sh
```

### 权限问题

```bash
# 使用 sudo
sudo ./scripts/run-all.sh

# 或配置 perf 权限
sudo sysctl -w kernel.perf_event_paranoid=-1
```

### 测试失败

```bash
# 查看详细错误
cat results/*/report_*.txt

# 单独运行失败的测试
sudo ./scripts/网络/network-test.sh
```

## 参考资料

- [测试指南](TESTING_GUIDE.md)
- [工具使用说明](../tools/README.md)
- [主文档](../README.md)
- [快速开始](../QUICKSTART.md)

---

**文档版本**: 2.0
**最后更新**: 2026-04-18
