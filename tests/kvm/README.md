# KVM 虚拟化测试套件

## 概述

本测试套件提供了完整的KVM (Kernel-based Virtual Machine) 虚拟化测试工具，包括基础功能测试、嵌套虚拟化测试和性能评估。

## 目录结构

```
kvm/
├── README.md                       # 本文件
├── scripts/
│   ├── test_kvm_basic.sh           # KVM基础功能测试
│   └── test_nested_virt.sh         # 嵌套虚拟化测试
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
