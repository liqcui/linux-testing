# BCC 工具内核兼容性指南

## 概述

BCC 工具依赖内核函数名和签名。随着内核版本更新，某些函数可能被重命名、移除或修改，导致 BCC 工具无法附加 kprobe。本文档说明常见的兼容性问题和解决方案。

## 常见问题

### 1. account_page_dirtied 函数不存在

**错误信息：**
```
cannot attach kprobe, probe entry may not exist
Exception: Failed to attach BPF program b'do_count' to kprobe b'account_page_dirtied'
```

**原因：**
- 在 Linux 5.16+ 内核中，`account_page_dirtied` 被重命名为 `folio_account_dirtied`
- 这是内核从 page 结构迁移到 folio 结构的一部分

**影响工具：**
- cachestat
- fileslower
- 其他跟踪脏页的工具

**解决方案：**

#### 方案 1: 使用兼容版本（推荐）

我们提供了 `cachestat_wrapper.py`，自动检测并使用正确的内核函数：

```bash
cd tests/bcc
sudo python3 cachestat_wrapper.py 1
```

#### 方案 2: 手动修改 BCC 工具

编辑 `/usr/share/bcc/tools/cachestat`，查找：
```python
b.attach_kprobe(event="account_page_dirtied", fn_name="do_count")
```

替换为内核函数检测代码：
```python
# 检测并使用正确的函数
if BPF.get_kprobe_functions(b'folio_account_dirtied'):
    b.attach_kprobe(event="folio_account_dirtied", fn_name="do_count")
elif BPF.get_kprobe_functions(b'account_page_dirtied'):
    b.attach_kprobe(event="account_page_dirtied", fn_name="do_count")
else:
    print("警告: 无法找到脏页跟踪函数")
```

### 2. 函数签名变化

**问题：**
某些内核函数的参数类型或数量在不同版本中变化。

**示例：**
- `tcp_v4_connect()` 的参数在某些内核版本中不同
- `do_sys_open()` 在 5.6+ 变成了 `do_sys_openat2()`

**解决方案：**
使用 tracepoint 而非 kprobe，因为 tracepoint 接口更稳定：

```python
# 不稳定 - 使用 kprobe
b.attach_kprobe(event="do_sys_open", fn_name="trace_entry")

# 稳定 - 使用 tracepoint
b.attach_tracepoint(tp="syscalls:sys_enter_open", fn_name="trace_entry")
b.attach_tracepoint(tp="syscalls:sys_enter_openat", fn_name="trace_entry")
```

### 3. 内核函数完全移除

**问题：**
某些函数在新内核中被完全移除或内联。

**示例：**
- `__do_page_cache_readahead` 在某些内核中被内联
- 旧的网络函数被新的实现替代

**解决方案：**
使用更高级的跟踪点或替代函数：

```python
# 如果旧函数不存在
if not BPF.get_kprobe_functions(b'old_function'):
    # 尝试新函数
    b.attach_kprobe(event="new_function", fn_name="handler")
```

## 内核版本对照表

### 脏页跟踪函数

| 内核版本 | 函数名 | 说明 |
|---------|--------|------|
| < 5.16 | `account_page_dirtied` | 传统实现 |
| >= 5.16 | `folio_account_dirtied` | 新的 folio 结构 |
| 更老版本 | `__set_page_dirty` | 备选函数 |

### 文件系统函数

| 内核版本 | open 系列函数 | 说明 |
|---------|--------------|------|
| < 5.6 | `do_sys_open` | 传统实现 |
| >= 5.6 | `do_sys_openat2` | 新实现，支持更多选项 |
| 所有版本 | `syscalls:sys_enter_open*` | 稳定的 tracepoint |

### 网络函数

| 内核版本 | TCP 连接函数 | 说明 |
|---------|-------------|------|
| < 4.16 | `tcp_v4_connect` | IPv4 |
| < 4.16 | `tcp_v6_connect` | IPv6 |
| >= 4.16 | 可能需要额外处理 | 函数签名变化 |
| 所有版本 | `sock:inet_sock_set_state` | 推荐使用 tracepoint |

## 检查内核函数

### 方法 1: 使用 /proc/kallsyms

```bash
# 查找特定函数
grep account_page_dirtied /proc/kallsyms
grep folio_account_dirtied /proc/kallsyms

# 查找函数模式
grep -i "page.*dirty" /proc/kallsyms
```

### 方法 2: 使用 bpftrace

```bash
# 列出所有可用的 kprobe
sudo bpftrace -l 'kprobe:*' | grep dirty

# 搜索特定模式
sudo bpftrace -l 'kprobe:*account*'
```

### 方法 3: 使用 available_filter_functions

```bash
# 查看所有可跟踪的函数（需要 root）
sudo cat /sys/kernel/debug/tracing/available_filter_functions | grep dirty
```

### 方法 4: Python BCC 工具

```python
from bcc import BPF

# 检查函数是否存在
if BPF.get_kprobe_functions(b'folio_account_dirtied'):
    print("folio_account_dirtied 存在")
else:
    print("folio_account_dirtied 不存在")
```

## 编写兼容的 BCC 工具

### 最佳实践

1. **优先使用 tracepoint**
   - 接口稳定，不随内核版本变化
   - 开销通常更低
   - 参数经过验证

2. **动态检测内核函数**
   ```python
   def get_available_function(candidates):
       """从候选列表中找到第一个可用的函数"""
       for func in candidates:
           if BPF.get_kprobe_functions(func.encode()):
               return func
       return None

   dirty_func = get_available_function([
       'folio_account_dirtied',
       'account_page_dirtied',
       '__set_page_dirty'
   ])
   ```

3. **提供降级路径**
   ```python
   if dirty_func:
       b.attach_kprobe(event=dirty_func, fn_name="trace_dirty")
   else:
       print("警告: 脏页跟踪不可用，某些统计将缺失")
   ```

4. **添加内核版本检查**
   ```python
   import platform
   kernel_version = platform.release()
   major, minor = map(int, kernel_version.split('.')[:2])

   if major >= 5 and minor >= 16:
       # 使用新函数
       pass
   else:
       # 使用旧函数
       pass
   ```

### 示例：兼容的 cachestat

```python
#!/usr/bin/env python3
from bcc import BPF

def get_dirty_function():
    """检测并返回可用的脏页跟踪函数"""
    candidates = [
        b'folio_account_dirtied',  # 5.16+
        b'account_page_dirtied',   # < 5.16
        b'__set_page_dirty',       # fallback
    ]

    for func in candidates:
        if BPF.get_kprobe_functions(func):
            return func.decode()
    return None

# BPF 程序
bpf_text = """
// ... BPF 代码 ...
"""

b = BPF(text=bpf_text)

# 必需的探针
b.attach_kprobe(event="add_to_page_cache_lru", fn_name="count_add")
b.attach_kprobe(event="mark_page_accessed", fn_name="count_hit")

# 可选的探针
dirty_func = get_dirty_function()
if dirty_func:
    b.attach_kprobe(event=dirty_func, fn_name="count_dirty")
    print(f"使用脏页函数: {dirty_func}")
else:
    print("警告: 脏页跟踪不可用")

# ... 其余代码 ...
```

## 工具路径配置

### 设置默认 BCC 工具路径

在脚本中添加：

```bash
# 设置 BCC 工具默认路径
BCC_TOOLS_PATH="${BCC_TOOLS_PATH:-/usr/share/bcc/tools}"

# 添加到 PATH
if [[ -d "$BCC_TOOLS_PATH" ]]; then
    if [[ ":$PATH:" != *":$BCC_TOOLS_PATH:"* ]]; then
        export PATH="$BCC_TOOLS_PATH:$PATH"
    fi
fi
```

### 在 shell 配置中永久设置

在 `~/.bashrc` 或 `~/.bash_profile` 中添加：

```bash
# BCC 工具路径
export BCC_TOOLS_PATH="/usr/share/bcc/tools"
export PATH="$BCC_TOOLS_PATH:$PATH"
```

## 故障排查流程

当 BCC 工具报错时，按以下步骤排查：

### 1. 确认错误类型

```bash
# 运行工具并查看详细错误
sudo tool_name 2>&1 | tee error.log
```

### 2. 检查内核函数

```bash
# 提取错误中的函数名
FUNC_NAME="account_page_dirtied"

# 检查是否存在
grep -w "$FUNC_NAME" /proc/kallsyms
```

### 3. 查找替代函数

```bash
# 搜索相关函数
grep -i "account.*dirty\|dirty.*page\|folio.*dirty" /proc/kallsyms
```

### 4. 检查 tracepoint 可用性

```bash
# 查看可用的 tracepoint
sudo ls /sys/kernel/debug/tracing/events/

# 查看具体事件
sudo ls /sys/kernel/debug/tracing/events/syscalls/ | grep open
```

### 5. 使用兼容版本

```bash
# 使用我们提供的兼容工具
cd tests/bcc
sudo python3 cachestat_wrapper.py
```

## 常用工具兼容性

| 工具 | 常见问题 | 解决方案 | 兼容版本 |
|-----|---------|---------|---------|
| cachestat | account_page_dirtied | cachestat_wrapper.py | ✓ |
| execsnoop | 通常无问题 | - | ✓ |
| opensnoop | do_sys_open | 使用 tracepoint | ✓ |
| biosnoop | 通常无问题 | - | ✓ |
| tcpconnect | 函数签名变化 | 使用 tracepoint | ✓ |
| profile | 通常无问题 | - | ✓ |

## 参考资料

- [BCC 内核版本兼容性](https://github.com/iovisor/bcc/blob/master/docs/kernel-versions.md)
- [Linux 内核更新日志](https://kernelnewbies.org/)
- [Folio 结构说明](https://lwn.net/Articles/849538/)
- [BCC 问题跟踪](https://github.com/iovisor/bcc/issues)

## 贡献

如果您发现新的兼容性问题或解决方案，欢迎：

1. 更新此文档
2. 创建兼容版本工具
3. 提交 PR 到项目

---

更新日期：2026-04-18
