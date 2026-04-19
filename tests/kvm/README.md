# KVM 虚拟化测试套件

## 概述

本测试套件提供了完整的KVM (Kernel-based Virtual Machine) 虚拟化测试工具，包括基础功能测试、嵌套虚拟化测试、热迁移测试和性能评估。

## 目录结构

```
kvm/
├── README.md                       # 本文件
├── scripts/
│   ├── test_kvm_basic.sh           # KVM基础功能测试
│   ├── test_nested_virt.sh         # 嵌套虚拟化测试
│   └── test_live_migration.sh      # 热迁移测试
├── images/                         # 虚拟机镜像目录
└── results/                        # 测试结果目录
```

## 前置条件

### 硬件要求

**CPU虚拟化支持：**
- **Intel:** VT-x技术 (vmx flag)
- **AMD:** AMD-V技术 (svm flag)

**检查方法：**
```bash
# 检查Intel VT-x
grep -q vmx /proc/cpuinfo && echo "支持VT-x" || echo "不支持VT-x"

# 检查AMD-V
grep -q svm /proc/cpuinfo && echo "支持AMD-V" || echo "不支持AMD-V"

# 查看所有CPU flags
cat /proc/cpuinfo | grep flags | head -1
```

**BIOS设置：**
- 确保在BIOS中启用了虚拟化功能
- Intel: "Intel Virtualization Technology"
- AMD: "SVM Mode" 或 "AMD-V"

### 软件要求

**内核支持：**
```bash
# 检查内核配置
zcat /proc/config.gz | grep -E "CONFIG_KVM|CONFIG_VIRT"

# 必需的配置
CONFIG_KVM=m
CONFIG_KVM_INTEL=m  # Intel CPU
CONFIG_KVM_AMD=m    # AMD CPU
```

**安装依赖：**

```bash
# Ubuntu/Debian
sudo apt-get install qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# RHEL/CentOS
sudo yum install qemu-kvm qemu-img libvirt libvirt-python libguestfs-tools virt-install

# Fedora
sudo dnf install @virtualization
```

## 测试1: KVM基础功能

### 功能特性

- CPU虚拟化支持检测
- KVM模块加载验证
- /dev/kvm设备节点检查
- QEMU/KVM安装验证
- libvirt环境检查
- KVM参数查看
- 测试镜像创建
- CPU虚拟化特性检查

### 运行测试

```bash
cd scripts
sudo ./test_kvm_basic.sh
```

### 手动操作

#### 加载KVM模块

```bash
# Intel CPU
sudo modprobe kvm-intel

# AMD CPU
sudo modprobe kvm-amd

# 验证
lsmod | grep kvm
```

#### 检查/dev/kvm权限

```bash
# 查看设备
ls -l /dev/kvm

# 添加用户到kvm组
sudo usermod -a -G kvm $USER

# 重新登录后生效
```

#### 创建虚拟机镜像

```bash
# 创建qcow2镜像
qemu-img create -f qcow2 vm.qcow2 20G

# 查看镜像信息
qemu-img info vm.qcow2

# 转换镜像格式
qemu-img convert -f raw -O qcow2 source.img dest.qcow2
```

#### 启动简单虚拟机

```bash
# 使用QEMU直接启动
qemu-system-x86_64 \
    -enable-kvm \
    -m 2048 \
    -smp 2 \
    -drive file=vm.qcow2,format=qcow2 \
    -cdrom ubuntu.iso \
    -boot d \
    -nographic

# 使用virt-install
virt-install \
    --name test-vm \
    --ram 2048 \
    --vcpus 2 \
    --disk path=vm.qcow2,format=qcow2 \
    --cdrom ubuntu.iso \
    --graphics none
```

### KVM架构

```
用户空间
┌─────────────────────────────────┐
│  QEMU/KVM 进程                   │
│  ┌───────────────────────────┐  │
│  │  设备模拟                  │  │
│  │  I/O处理                   │  │
│  └───────────────────────────┘  │
└──────────┬──────────────────────┘
           │ ioctl(/dev/kvm)
───────────┼───────────────────────
内核空间   │
┌──────────▼──────────────────────┐
│  KVM 内核模块                    │
│  ┌───────────────────────────┐  │
│  │  VM管理                    │  │
│  │  CPU虚拟化                 │  │
│  │  内存虚拟化                │  │
│  └───────────────────────────┘  │
└──────────┬──────────────────────┘
           │ VT-x/AMD-V
───────────┼───────────────────────
硬件       │
┌──────────▼──────────────────────┐
│  CPU 硬件虚拟化                  │
│  Intel VT-x / AMD-V              │
└─────────────────────────────────┘
```

### CPU虚拟化特性

| 特性 | Intel | AMD | 说明 |
|------|-------|-----|------|
| 基础虚拟化 | VT-x (vmx) | AMD-V (svm) | 必需 |
| 嵌套页表 | EPT | NPT | 性能关键 |
| VPID | ✓ | - | TLB优化 |
| PCID | ✓ | ✓ | 进程上下文标识 |
| APICv | ✓ | AVIC | 中断虚拟化 |

### 测试结果

- `kvm-modules.txt` - 已加载的KVM模块
- `dev-kvm.txt` - /dev/kvm设备信息
- `libvirt-version.txt` - libvirt版本
- `kvm-parameters.txt` - KVM模块参数
- `image-info.txt` - 测试镜像信息
- `cpu-features.txt` - CPU虚拟化特性
- `summary.txt` - 测试总结

## 测试2: 嵌套虚拟化

### 功能特性

- 嵌套虚拟化参数检查
- 自动启用nested支持
- L1/L2配置示例
- 性能影响分析
- 验证方法说明

### 运行测试

```bash
cd scripts
sudo ./test_nested_virt.sh
```

### 手动操作

#### 启用嵌套虚拟化

```bash
# Intel CPU
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm.conf

# AMD CPU
echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm.conf

# 重新加载模块
sudo modprobe -r kvm_intel  # 或 kvm_amd
sudo modprobe kvm_intel     # 或 kvm_amd

# 验证
cat /sys/module/kvm_intel/parameters/nested  # 应显示 Y 或 1
```

#### 创建L1虚拟机（支持嵌套）

```bash
# QEMU命令行
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -drive file=l1-vm.qcow2,format=qcow2 \
    -nographic
```

**libvirt XML配置：**
```xml
<domain type='kvm'>
  <name>l1-vm</name>
  <memory unit='GiB'>4</memory>
  <vcpu>4</vcpu>
  <cpu mode='host-passthrough' check='none'/>
  ...
</domain>
```

#### 在L1中创建L2虚拟机

**在L1虚拟机内：**
```bash
# 1. 检查虚拟化支持
grep -E 'vmx|svm' /proc/cpuinfo

# 2. 安装KVM
sudo apt-get install qemu-kvm

# 3. 加载KVM模块
sudo modprobe kvm_intel  # 或 kvm_amd

# 4. 创建L2虚拟机
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -m 1024 \
    -drive file=l2-vm.qcow2,format=qcow2 \
    -nographic
```

### 嵌套虚拟化架构

```
┌─────────────────────────────────┐
│  L0 - 物理主机 (Hypervisor)      │
│  ┌───────────────────────────┐  │
│  │  L1 - 虚拟机 (Guest+KVM)   │  │
│  │  ┌─────────────────────┐  │  │
│  │  │  L2 - 嵌套虚拟机     │  │  │
│  │  │                      │  │  │
│  │  │  应用程序             │  │  │
│  │  └─────────────────────┘  │  │
│  │  KVM模块                   │  │
│  └───────────────────────────┘  │
│  KVM模块                         │
└─────────────────────────────────┘
```

### 性能考虑

**性能层次：**
- 物理机 (L0): 100%
- L1虚拟机: 90-95%
- L2虚拟机: 70-85%

**优化建议：**
1. 启用EPT/NPT（嵌套页表）
2. 使用virtio驱动
3. 合理分配CPU和内存
4. 避免过深嵌套（不要超过L2）

### 应用场景

1. **云计算平台**
   - 用户需要在云主机中运行容器或虚拟机
   - OpenStack, AWS等

2. **开发测试**
   - 虚拟化软件开发
   - 多层次环境测试

3. **安全研究**
   - 恶意软件分析沙箱
   - 安全隔离环境

### 测试结果

- `principles.txt` - 嵌套虚拟化原理
- `nested-config.txt` - 配置信息
- `l1-config.txt` - L1/L2配置示例
- `performance.txt` - 性能分析
- `verification.txt` - 验证方法
- `troubleshooting.txt` - 故障排查
- `summary.txt` - 测试总结

## 测试3: KVM热迁移

### 功能特性

- 热迁移原理说明（Pre-copy, Post-copy）
- 环境要求检查（网络、存储、CPU兼容性）
- QEMU热迁移配置和命令
- libvirt热迁移多种方式（TCP、SSH、TLS）
- 性能优化建议（压缩、RDMA、并行传输）
- 故障排查指南
- 安全考虑（加密、认证）

### 运行测试

```bash
cd scripts
sudo ./test_live_migration.sh
```

### 手动操作

#### QEMU热迁移（单机模拟）

**启动源VM：**
```bash
qemu-system-x86_64 \
    -enable-kvm \
    -m 512 \
    -smp 2 \
    -drive file=vm.qcow2,format=qcow2 \
    -monitor telnet:127.0.0.1:4445,server,nowait \
    -vnc :0 \
    -name source-vm
```

**启动目标VM（等待迁移）：**
```bash
qemu-system-x86_64 \
    -enable-kvm \
    -m 512 \
    -smp 2 \
    -drive file=vm.qcow2,format=qcow2 \
    -incoming tcp:0.0.0.0:4444 \
    -monitor telnet:127.0.0.1:4446,server,nowait \
    -vnc :1 \
    -name dest-vm
```

**执行迁移：**
```bash
telnet localhost 4445
(qemu) migrate -d tcp:localhost:4444
(qemu) info migrate
```

#### libvirt热迁移

**SSH迁移（推荐）：**
```bash
# 配置SSH密钥认证
ssh-keygen
ssh-copy-id root@target-host

# 执行迁移
virsh migrate --live \
    --verbose \
    vm-name \
    qemu+ssh://target-host/system
```

**TCP迁移：**
```bash
# 目标主机配置 /etc/libvirt/libvirtd.conf
listen_tls = 0
listen_tcp = 1
tcp_port = "16509"
auth_tcp = "none"

# 重启libvirtd
systemctl restart libvirtd

# 执行迁移
virsh migrate --live vm-name qemu+tcp://target-host/system
```

**带存储迁移：**
```bash
virsh migrate --live --copy-storage-all vm-name qemu+ssh://target-host/system
```

**监控迁移进度：**
```bash
# 实时监控
watch -n 1 'virsh domjobinfo vm-name'

# 查看已完成的迁移统计
virsh domjobinfo vm-name --completed
```

**取消迁移：**
```bash
virsh domjobabort vm-name
```

### 热迁移架构

```
源主机 (Source)                     目标主机 (Target)
┌─────────────────────┐            ┌─────────────────────┐
│  运行中的VM          │            │  等待接收的VM        │
│  ┌───────────────┐  │            │  ┌───────────────┐  │
│  │ 应用程序       │  │  迁移流    │  │ 应用程序       │  │
│  │ 操作系统       │◄─┼────────────┼─►│ 操作系统       │  │
│  └───────────────┘  │            │  └───────────────┘  │
│  内存/CPU/设备      │            │  内存/CPU/设备      │
└─────────────────────┘            └─────────────────────┘
         │                                  │
         └──────── 共享存储 ────────────────┘
              (NFS/iSCSI/Ceph)
```

### 迁移过程

```
阶段1: 预迁移 (Pre-migration)
├─ 在目标主机启动VM实例（暂停状态）
├─ 建立源和目标之间的迁移连接
└─ 验证CPU兼容性、存储访问等

阶段2: 迭代拷贝 (Iterative Copy)
├─ 第1轮: 复制所有内存页到目标
├─ 第2轮: 复制第1轮中被修改的脏页
├─ 第3轮: 复制第2轮中的脏页
└─ ... 持续迭代直到脏页率降低

阶段3: 停止并拷贝 (Stop-and-Copy)
├─ 暂停源VM
├─ 传输剩余脏页
├─ 传输CPU状态、设备状态
└─ 停机时间窗口（100-500ms）

阶段4: 提交 (Commit)
├─ 在目标主机激活VM
├─ 销毁源VM
└─ 完成迁移
```

### 热迁移类型

**Pre-copy迁移：**
- 先复制内存，VM继续运行
- 多轮迭代复制脏页
- 适合一般应用
- 停机时间短

**Post-copy迁移：**
- 先迁移CPU状态，立即启动目标VM
- 按需从源主机拉取内存页
- 适合内存密集型应用
- 总迁移时间更短，但依赖网络

**存储迁移：**
- 同时迁移VM和磁盘
- 不需要共享存储
- 时间较长（取决于磁盘大小）

### 性能优化

**内存优化：**
```bash
# 启用压缩
virsh migrate --live --compressed vm-name target

# 设置迁移带宽（MB/s）
virsh migrate-setspeed vm-name 1000

# 设置最大停机时间（毫秒）
virsh migrate-setmaxdowntime vm-name 500

# QEMU monitor设置
(qemu) migrate_set_speed 1000M
(qemu) migrate_set_downtime 0.5
```

**网络优化：**
```bash
# 使用RDMA（如果硬件支持）
virsh migrate --live --rdma-pin-all vm-name target

# 调整TCP参数
sysctl -w net.core.rmem_max=134217728
sysctl -w net.core.wmem_max=134217728
sysctl -w net.ipv4.tcp_rmem='4096 87380 67108864'
sysctl -w net.ipv4.tcp_wmem='4096 65536 67108864'
```

**迁移策略：**
```bash
# Post-copy模式（适合内存密集型）
virsh migrate --live --postcopy vm-name target

# Auto-converge（自动调整vCPU降低脏页率）
virsh migrate --live --auto-converge vm-name target

# 并行迁移
virsh migrate --live --parallel --parallel-connections 4 vm-name target
```

### 性能指标

| 指标 | 典型值 | 说明 |
|------|--------|------|
| 总迁移时间 | 10-60秒 | 取决于内存大小和网络 |
| 停机时间 | 100-500ms | VM暂停时间 |
| 传输速度 | 80-800MB/s | 取决于网络带宽 |
| 迭代轮次 | 2-5轮 | 取决于脏页率 |

**影响因素：**
- VM内存大小
- 工作负载类型（内存密集型更慢）
- 网络带宽和延迟
- CPU性能（压缩场景）
- 是否使用压缩/RDMA

### 安全考虑

**风险：**
1. 明文传输 - TCP迁移未加密
2. 未授权迁移 - 无认证的libvirtd
3. 中间人攻击 - 迁移流量被劫持

**安全措施：**

**使用TLS加密：**
```bash
# /etc/libvirt/libvirtd.conf
listen_tls = 1
key_file = "/etc/pki/libvirt/private/serverkey.pem"
cert_file = "/etc/pki/libvirt/servercert.pem"
ca_file = "/etc/pki/CA/cacert.pem"

# 执行迁移
virsh migrate --live qemu+tls://target/system
```

**使用SSH隧道（推荐）：**
```bash
virsh migrate --live qemu+ssh://target/system
```

**启用SASL认证：**
```bash
# /etc/libvirt/libvirtd.conf
auth_tcp = "sasl"
```

**防火墙配置：**
```bash
# 仅允许特定主机
firewall-cmd --add-rich-rule='rule family="ipv4" \
    source address="192.168.1.0/24" \
    port port="16509" protocol="tcp" accept'
```

### 常见问题

**问题1: CPU不兼容**
```
错误: internal error: unable to execute QEMU command 'migrate'
原因: 源和目标CPU型号不同
```

**解决：**
```bash
# 使用CPU兼容模式
virsh edit vm-name
<cpu mode='custom' match='exact'>
  <model>qemu64</model>
</cpu>
```

**问题2: 迁移超时**
```
现象: 迁移长时间不完成
原因: 脏页产生速度 > 传输速度
```

**解决：**
```bash
# 增加迁移带宽
virsh migrate-setspeed vm-name 2000

# 使用auto-converge
virsh migrate --live --auto-converge vm-name target

# 使用post-copy
virsh migrate --live --postcopy vm-name target
```

**问题3: 网络连接失败**
```
错误: Unable to connect to server
原因: 防火墙/网络不通
```

**解决：**
```bash
# 检查防火墙
firewall-cmd --add-port=16509/tcp --permanent
firewall-cmd --reload

# 测试连通性
nc -zv target-host 16509

# 使用SSH迁移
virsh migrate --live qemu+ssh://target/system
```

**问题4: 存储访问失败**
```
错误: Cannot access storage file
原因: 目标主机无法访问镜像
```

**解决：**
```bash
# 使用共享存储（NFS/iSCSI）
# 或使用存储迁移
virsh migrate --live --copy-storage-all vm-name target
```

### 测试结果

- `principles.txt` - 热迁移原理
- `requirements.txt` - 环境要求
- `qemu-migration.txt` - QEMU迁移命令
- `libvirt-migration.txt` - libvirt迁移方式
- `optimization.txt` - 性能优化
- `troubleshooting.txt` - 故障排查
- `test-examples.txt` - 测试示例
- `benchmarks.txt` - 性能基准
- `security.txt` - 安全考虑
- `summary.txt` - 测试总结

## 常用QEMU参数

### 基础参数

```bash
-enable-kvm          # 启用KVM加速
-m 2048              # 内存2GB
-smp 4               # 4个vCPU
-cpu host            # 使用宿主机CPU型号
```

### CPU相关

```bash
-cpu host            # 宿主机CPU（推荐用于嵌套虚拟化）
-cpu host-passthrough  # 完全透传CPU特性
-cpu qemu64          # QEMU模拟的CPU
-smp cores=2,threads=2,sockets=1  # 拓扑配置
```

### 磁盘相关

```bash
-drive file=vm.qcow2,format=qcow2,if=virtio  # virtio磁盘
-cdrom ubuntu.iso                             # 光盘
-boot d                                       # 从光盘启动
-boot c                                       # 从硬盘启动
```

### 网络相关

```bash
-net nic -net user                 # 用户模式网络
-net nic -net bridge,br=virbr0     # 桥接网络
-netdev tap,id=net0 -device virtio-net-pci,netdev=net0  # TAP设备
```

### 显示相关

```bash
-nographic           # 无图形界面
-vnc :1              # VNC显示
-display gtk         # GTK图形界面
-serial mon:stdio    # 串口重定向到stdio
```

## libvirt常用命令

### 虚拟机管理

```bash
# 列出虚拟机
virsh list --all

# 启动虚拟机
virsh start vm-name

# 停止虚拟机
virsh shutdown vm-name

# 强制关闭
virsh destroy vm-name

# 删除虚拟机
virsh undefine vm-name

# 查看虚拟机信息
virsh dominfo vm-name

# 连接虚拟机控制台
virsh console vm-name
```

### 快照管理

```bash
# 创建快照
virsh snapshot-create-as vm-name snapshot1 "description"

# 列出快照
virsh snapshot-list vm-name

# 恢复快照
virsh snapshot-revert vm-name snapshot1

# 删除快照
virsh snapshot-delete vm-name snapshot1
```

### 网络管理

```bash
# 列出网络
virsh net-list --all

# 启动网络
virsh net-start default

# 自动启动网络
virsh net-autostart default

# 查看网络信息
virsh net-info default
```

## 故障排查

### KVM模块加载失败

**现象：** `modprobe kvm_intel` 失败

**原因：**
1. BIOS未启用虚拟化
2. 内核不支持KVM
3. CPU不支持虚拟化

**解决：**
```bash
# 检查CPU支持
grep -E 'vmx|svm' /proc/cpuinfo

# 检查内核模块
ls /lib/modules/$(uname -r)/kernel/arch/x86/kvm/

# 查看错误信息
dmesg | grep kvm
```

### /dev/kvm权限错误

**现象：** `Permission denied: /dev/kvm`

**解决：**
```bash
# 检查权限
ls -l /dev/kvm

# 添加用户到kvm组
sudo usermod -a -G kvm $USER

# 或临时修改权限（不推荐）
sudo chmod 666 /dev/kvm
```

### 虚拟机性能差

**原因：**
1. 未启用KVM（使用纯软件模拟）
2. CPU未分配足够核心
3. 未使用virtio驱动

**解决：**
```bash
# 确认使用KVM
ps aux | grep qemu | grep -- -enable-kvm

# 使用virtio设备
-drive file=vm.qcow2,format=qcow2,if=virtio
-netdev tap,id=net0 -device virtio-net-pci,netdev=net0

# 启用huge pages
echo 1024 > /proc/sys/vm/nr_hugepages
-mem-path /dev/hugepages
```

### 嵌套虚拟化不工作

**现象：** L1中无vmx/svm flag

**解决：**
```bash
# 1. 确认L0启用nested
cat /sys/module/kvm_intel/parameters/nested

# 2. L1使用正确的CPU参数
-cpu host   # 或 -cpu host-passthrough

# 3. libvirt配置
<cpu mode='host-passthrough'/>
```

## 性能优化

### CPU优化

```bash
# CPU绑定
virsh vcpupin vm-name 0 1  # 将vCPU 0绑定到物理CPU 1

# NUMA优化
numactl --cpunodebind=0 --membind=0 qemu-system-x86_64 ...
```

### 内存优化

```bash
# 使用huge pages
echo 1024 > /proc/sys/vm/nr_hugepages
-mem-path /dev/hugepages

# 内存气球
-device virtio-balloon-pci
```

### I/O优化

```bash
# 使用virtio
-device virtio-blk-pci,drive=hd0
-drive id=hd0,file=vm.qcow2,format=qcow2,if=none

# 使用O_DIRECT
-drive file=vm.qcow2,format=qcow2,cache=none,aio=native
```

## 参考资料

- [KVM Official Documentation](https://www.linux-kvm.org/)
- [QEMU Documentation](https://www.qemu.org/documentation/)
- [libvirt Documentation](https://libvirt.org/docs.html)
- [Intel VT-x Specification](https://www.intel.com/content/www/us/en/virtualization/virtualization-technology/intel-virtualization-technology.html)
- [Red Hat Virtualization Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/)

---

**更新日期：** 2026-04-19
**版本：** 1.0
