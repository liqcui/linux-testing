# Namespace 测试套件

## 概述

本测试套件提供了完整的Linux Namespace测试工具，包括PID、Network、UTS、Mount、IPC和User namespace的测试。

## 目录结构

```
namespace/
├── README.md                       # 本文件
├── programs/
│   ├── namespace_test.c            # Namespace测试程序
│   └── Makefile                    # 编译配置
├── scripts/
│   ├── test_pid_namespace.sh       # PID namespace测试
│   ├── test_network_namespace.sh   # Network namespace测试
│   ├── test_uts_namespace.sh       # UTS namespace测试
│   └── test_mount_namespace.sh     # Mount namespace测试
└── results/                        # 测试结果目录
```

## Namespace类型说明

Linux支持以下几种namespace类型:

| Namespace | 隔离内容 | 标识符 | 内核版本 |
|-----------|---------|--------|---------|
| PID | 进程ID | CLONE_NEWPID | 2.6.24 |
| Network | 网络设备、协议栈、端口 | CLONE_NEWNET | 2.6.29 |
| UTS | 主机名和域名 | CLONE_NEWUTS | 2.6.19 |
| Mount | 挂载点 | CLONE_NEWNS | 2.4.19 |
| IPC | System V IPC、POSIX消息队列 | CLONE_NEWIPC | 2.6.19 |
| User | 用户和组ID | CLONE_NEWUSER | 3.8 |
| Cgroup | Cgroup根目录 | CLONE_NEWCGROUP | 4.6 |

## 前置条件

### 系统要求

- Linux内核 >= 3.8（完整支持所有namespace类型）
- root权限（某些操作需要）
- gcc编译器

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install build-essential iproute2 util-linux

# RHEL/CentOS/Fedora
sudo yum install gcc make iproute util-linux
```

### 检查Namespace支持

```bash
# 查看所有namespace
ls -l /proc/self/ns/

# 检查特定namespace
ls -l /proc/self/ns/pid    # PID namespace
ls -l /proc/self/ns/net    # Network namespace
ls -l /proc/self/ns/uts    # UTS namespace
ls -l /proc/self/ns/mnt    # Mount namespace
ls -l /proc/self/ns/ipc    # IPC namespace
ls -l /proc/self/ns/user   # User namespace
```

## 测试程序

### namespace_test - 通用Namespace测试程序

**编译：**
```bash
cd programs
make
```

**用法：**
```bash
./namespace_test [选项]

选项:
  -p    使用PID namespace
  -n    使用Network namespace
  -u    使用UTS namespace (hostname)
  -i    使用IPC namespace
  -m    使用Mount namespace
  -U    使用User namespace
  -c    在新namespace中执行的命令
  -h    显示帮助
```

**示例：**
```bash
# PID namespace
sudo ./namespace_test -p -c "ps aux"

# Network namespace
sudo ./namespace_test -n -c "ip link show"

# 组合多个namespace
sudo ./namespace_test -p -u -n -c "hostname; ps aux; ip link"

# User namespace（不需要root）
./namespace_test -U -c "id"
```

## 测试1: PID Namespace

### 功能特性

- PID隔离（新namespace中PID从1开始）
- 进程树隔离
- 嵌套PID namespace
- /proc文件系统隔离

### 运行测试

```bash
cd scripts
sudo ./test_pid_namespace.sh
```

### 手动操作

#### 使用unshare创建PID namespace

```bash
# 创建新PID namespace
sudo unshare -p -f --mount-proc /bin/bash

# 在新namespace中
ps aux                  # 应该只看到很少的进程
echo $$                 # 应该显示PID 1（init进程）
```

#### 查看PID namespace

```bash
# 当前进程的PID namespace
ls -l /proc/self/ns/pid

# 特定进程的PID namespace
ls -l /proc/<PID>/ns/pid

# 比较两个进程是否在同一namespace
# 如果inode相同，则在同一namespace
```

#### 进入已存在的PID namespace

```bash
# 假设目标进程PID为1234
sudo nsenter -p -t 1234 /bin/bash

# 在目标namespace中执行命令
sudo nsenter -p -t 1234 ps aux
```

### 测试结果

- `basic-test.txt` - 基础PID namespace测试
- `pid-isolation.txt` - PID隔离验证
- `nested-pid.txt` - 嵌套namespace测试
- `pid-mount.txt` - PID + Mount组合
- `summary.txt` - 测试总结

## 测试2: Network Namespace

### 功能特性

- 网络接口隔离
- 路由表隔离
- 防火墙规则隔离
- Veth pair连接不同namespace
- 端口监听隔离

### 运行测试

```bash
cd scripts
sudo ./test_network_namespace.sh
```

### 手动操作

#### 创建Network namespace

```bash
# 创建named network namespace
sudo ip netns add myns

# 列出所有network namespace
ip netns list

# 在namespace中执行命令
sudo ip netns exec myns ip link show

# 删除namespace
sudo ip netns delete myns
```

#### 配置Veth pair

```bash
# 创建veth pair
sudo ip link add veth0 type veth peer name veth1

# 将veth1移到新namespace
sudo ip netns add myns
sudo ip link set veth1 netns myns

# 配置IP地址
sudo ip addr add 10.0.0.1/24 dev veth0
sudo ip link set veth0 up

sudo ip netns exec myns ip addr add 10.0.0.2/24 dev veth1
sudo ip netns exec myns ip link set veth1 up

# 测试连通性
ping -c 3 10.0.0.2
```

#### 网络配置

```bash
# 在namespace中启用loopback
sudo ip netns exec myns ip link set lo up

# 配置路由
sudo ip netns exec myns ip route add default via 10.0.0.1

# 配置NAT（允许namespace访问外网）
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

### 测试结果

- `original-network.txt` - 原始网络配置
- `netns-list.txt` - Namespace列表
- `new-netns-links.txt` - 新namespace网络接口
- `ping-test.txt` - 连通性测试
- `main-routes.txt`, `new-routes.txt` - 路由表对比
- `summary.txt` - 测试总结

## 测试3: UTS Namespace

### 功能特性

- 主机名隔离
- 域名隔离
- uname信息隔离
- 不影响网络配置

### 运行测试

```bash
cd scripts
sudo ./test_uts_namespace.sh
```

### 手动操作

#### 修改主机名

```bash
# 在新UTS namespace中修改主机名
sudo unshare -u /bin/bash

# 在新namespace中
hostname mycontainer
hostname                # 显示: mycontainer

# 退出namespace后，主机名恢复原样
```

#### 查看UTS namespace

```bash
# 当前UTS namespace
ls -l /proc/self/ns/uts

# 查看uname信息
uname -n               # nodename (主机名)
uname -a               # 所有信息
```

#### 应用场景

- 容器主机名隔离
- 多租户环境
- 测试环境隔离

### 测试结果

- `basic-test.txt` - 基础主机名修改
- `uts-pid-combined.txt` - UTS + PID组合
- `domainname-test.txt` - 域名测试
- `main-uname.txt`, `new-uname.txt` - uname对比
- `summary.txt` - 测试总结

## 测试4: Mount Namespace

### 功能特性

- 挂载点隔离
- Bind mount
- 只读挂载
- 挂载传播控制
- tmpfs、proc等文件系统

### 运行测试

```bash
cd scripts
sudo ./test_mount_namespace.sh
```

### 手动操作

#### 创建Mount namespace

```bash
# 创建新mount namespace
sudo unshare -m /bin/bash

# 在新namespace中挂载tmpfs
sudo mount -t tmpfs tmpfs /tmp/mydata

# 查看挂载点
mount | grep mydata

# 退出后，主namespace不受影响
```

#### Bind mount

```bash
# Bind mount允许在不同位置访问同一文件系统
sudo mount --bind /source/dir /target/dir

# 只读bind mount
sudo mount --bind /source/dir /target/dir
sudo mount -o remount,ro /target/dir
```

#### 挂载传播

```bash
# Shared - 挂载事件在命名空间间传播
sudo mount --make-shared /mnt/test

# Private - 挂载事件不传播（默认）
sudo mount --make-private /mnt/test

# Slave - 单向传播
sudo mount --make-slave /mnt/test
```

#### 重新挂载/proc

```bash
# 在PID namespace中重新挂载/proc
sudo unshare -p -m -f /bin/bash -c "
    umount /proc
    mount -t proc proc /proc
    ps aux
"
```

### 测试结果

- `original-mounts.txt` - 原始挂载点
- `basic-test.txt` - 基础挂载测试
- `bind-mount.txt` - Bind mount测试
- `readonly-mount.txt` - 只读挂载
- `proc-remount.txt` - /proc重新挂载
- `tmpfs-test.txt` - Tmpfs测试
- `summary.txt` - 测试总结

## 常见命令

### unshare - 创建新namespace

```bash
# 创建单个namespace
unshare -p /bin/bash              # PID namespace
unshare -n /bin/bash              # Network namespace
unshare -u /bin/bash              # UTS namespace
unshare -m /bin/bash              # Mount namespace
unshare -i /bin/bash              # IPC namespace
unshare -U /bin/bash              # User namespace

# 组合多个namespace
unshare -p -n -u -m /bin/bash     # PID + Net + UTS + Mount

# 常用选项
unshare -p -f /bin/bash           # -f fork新进程
unshare -p -f --mount-proc        # 重新挂载/proc
```

### nsenter - 进入已存在的namespace

```bash
# 进入特定namespace
nsenter -p -t <PID> /bin/bash     # PID namespace
nsenter -n -t <PID> /bin/bash     # Network namespace
nsenter -u -t <PID> /bin/bash     # UTS namespace
nsenter -m -t <PID> /bin/bash     # Mount namespace

# 进入所有namespace
nsenter -t <PID> -a /bin/bash

# 仅执行命令
nsenter -t <PID> -n ip link show
```

### ip netns - 管理Network namespace

```bash
# 创建namespace
ip netns add myns

# 列出namespace
ip netns list

# 执行命令
ip netns exec myns <command>

# 删除namespace
ip netns delete myns

# 监控namespace
ip netns monitor
```

### 查看namespace信息

```bash
# 列出进程的所有namespace
ls -l /proc/<PID>/ns/

# 查看namespace类型
readlink /proc/<PID>/ns/pid
readlink /proc/<PID>/ns/net

# 比较namespace
# 如果两个进程的namespace inode相同，说明在同一namespace
ls -li /proc/1/ns/pid
ls -li /proc/2/ns/pid
```

## 常见问题排查

### Namespace不存在

**现象：** `/proc/self/ns/` 目录为空或缺少某些文件

**解决：**
```bash
# 检查内核版本
uname -r

# 检查内核配置
grep CONFIG_NAMESPACES /boot/config-$(uname -r)
grep CONFIG_PID_NS /boot/config-$(uname -r)
grep CONFIG_NET_NS /boot/config-$(uname -r)

# 如果不支持，需要重新编译内核或升级系统
```

### 权限不足

**现象：** `unshare: unshare failed: Operation not permitted`

**解决：**
```bash
# 使用root权限
sudo unshare -p /bin/bash

# 或添加CAP_SYS_ADMIN capability
sudo setcap cap_sys_admin+ep /usr/bin/unshare

# User namespace不需要root（3.8+内核）
unshare -U /bin/bash
```

### Network namespace网络不通

**现象：** 无法ping通veth pair另一端

**解决：**
```bash
# 1. 检查接口状态
ip link show veth0
ip netns exec myns ip link show veth1

# 2. 确保接口已启用
ip link set veth0 up
ip netns exec myns ip link set veth1 up

# 3. 检查IP配置
ip addr show veth0
ip netns exec myns ip addr show veth1

# 4. 检查路由
ip route
ip netns exec myns ip route

# 5. 禁用防火墙测试
iptables -F
```

### Mount namespace权限错误

**现象：** `mount: permission denied`

**解决：**
```bash
# 使用root权限
sudo unshare -m /bin/bash

# 检查mount权限
cat /proc/self/mountinfo

# 确保有CAP_SYS_ADMIN
capsh --print | grep sys_admin
```

### PID namespace中init进程问题

**现象：** 子进程变成僵尸进程

**解决：**
```bash
# PID namespace中的PID 1进程必须回收子进程
# 使用-f选项fork新进程作为init
unshare -p -f --mount-proc /bin/bash

# 或使用专门的init程序
unshare -p -f /sbin/init
```

## 最佳实践

### 1. Namespace组合使用

容器通常组合使用多个namespace：

```bash
# 完整容器隔离
unshare -p -n -u -m -i -U -f --mount-proc /bin/bash
```

### 2. 清理资源

```bash
# Network namespace会持久化，需要手动删除
ip netns delete myns

# 其他namespace在进程退出后自动清理
```

### 3. 安全考虑

```bash
# User namespace允许非root用户创建其他namespace
# 但要注意权限映射

# 限制User namespace使用
echo 0 > /proc/sys/kernel/unprivileged_userns_clone
```

### 4. 调试技巧

```bash
# 查看进程所属的namespace
ls -l /proc/<PID>/ns/

# 进入进程的所有namespace调试
nsenter -t <PID> -a /bin/bash

# 监控namespace创建
strace -e clone,unshare <command>
```

### 5. 性能考虑

- Namespace切换有轻微开销
- Network namespace会复制完整网络栈
- Mount namespace会复制挂载表

## 容器技术基础

Namespace是容器技术的核心：

```bash
# Docker/Podman使用的namespace组合
docker run --rm -it ubuntu /bin/bash
# 等效于:
# - PID namespace
# - Network namespace
# - UTS namespace
# - Mount namespace
# - IPC namespace
# + Cgroups限制资源
```

## 参考资料

- [Linux Namespaces Documentation](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [Namespace API](https://lwn.net/Articles/531114/)
- [Understanding Linux Network Namespaces](https://www.opencloudblog.com/?p=66)
- [Mount Namespaces and Shared Subtrees](https://lwn.net/Articles/689856/)
- [User Namespaces](https://lwn.net/Articles/532593/)

---

**更新日期：** 2026-04-19
**版本：** 1.0
