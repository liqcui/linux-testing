# 设备驱动测试套件

## 概述

本测试套件提供了完整的I2C、SPI和GPIO设备测试工具，包括自动化测试脚本和专用测试程序。

## 目录结构

```
device-drivers/
├── README.md                    # 本文件
├── i2c/
│   ├── scripts/
│   │   └── test_i2c.sh          # I2C自动化测试脚本
│   └── results/                 # I2C测试结果
├── spi/
│   ├── programs/
│   │   └── spidev_test.c        # SPI测试程序
│   ├── scripts/
│   │   └── test_spi.sh          # SPI自动化测试脚本
│   └── results/                 # SPI测试结果
└── gpio/
    ├── programs/
    │   └── gpio_test.c          # GPIO测试程序
    ├── scripts/
    │   └── test_gpio.sh         # GPIO自动化测试脚本
    └── results/                 # GPIO测试结果
```

## I2C设备测试

### 功能特性

- 自动检测所有I2C总线
- 扫描并识别总线上的设备
- 设备寄存器读写测试
- 批量地址扫描
- 性能基准测试

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install i2c-tools

# RHEL/CentOS
sudo yum install i2c-tools

# Fedora
sudo dnf install i2c-tools
```

### 运行测试

```bash
cd i2c/scripts
sudo ./test_i2c.sh
```

### 手动测试命令

```bash
# 加载I2C驱动
sudo modprobe i2c-dev

# 列出I2C总线
ls /dev/i2c-*

# 扫描总线0
sudo i2cdetect -y 0

# 读取设备0x50的寄存器0x00
sudo i2cget -y 0 0x50 0x00

# 写入0xAA到寄存器0x00
sudo i2cset -y 0 0x50 0x00 0xAA

# 批量扫描设备
for addr in {0x03..0x77}; do
    sudo i2cget -y 0 $addr 0x00 2>/dev/null && echo "设备发现: 0x$(printf %02x $addr)"
done
```

### 测试结果

测试脚本生成以下报告：

- `scan-report.txt` - 总线扫描结果
- `read-test.txt` - 设备读取测试
- `bulk-scan.txt` - 批量地址扫描
- `performance.txt` - 性能测试数据
- `summary.txt` - 测试总结

### 预期输出

```
========================================
I2C设备测试
========================================

步骤 1: 检查依赖...
✓ i2c-tools 已安装

步骤 2: 加载I2C驱动...
✓ i2c-dev 模块已加载

步骤 3: 检测I2C总线...
找到 2 个I2C总线:
  - /dev/i2c-0
  - /dev/i2c-1

步骤 4: 扫描I2C设备...
扫描总线 0...
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: 50 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --

总线 0: 发现 1 个设备
```

## SPI设备测试

### 功能特性

- SPI设备自动检测
- 基础传输测试
- 回环测试（MISO/MOSI短接）
- 多速度测试（100KHz - 4MHz）
- 数据位测试（8/16 bit）
- SPI模式测试（Mode 0-3）
- 压力测试（1000次传输）

### 安装依赖

```bash
# 加载spidev驱动
sudo modprobe spidev

# 编译工具（通常已安装）
sudo apt-get install build-essential  # Ubuntu/Debian
sudo yum install gcc make              # RHEL/CentOS
```

### 运行测试

```bash
cd spi/scripts
sudo ./test_spi.sh
```

### 手动测试

```bash
# 编译测试程序
cd spi/programs
gcc -o spidev_test spidev_test.c

# 基础测试
sudo ./spidev_test -D /dev/spidev0.0 -v

# 回环测试
sudo ./spidev_test -D /dev/spidev0.0 -l -v

# 指定速度
sudo ./spidev_test -D /dev/spidev0.0 -s 1000000

# 多次迭代
sudo ./spidev_test -D /dev/spidev0.0 -n 1000

# 完整参数示例
sudo ./spidev_test -D /dev/spidev0.0 -s 1000000 -b 8 -H -O -v
```

### 程序参数

```
-D --device   设备路径 (默认: /dev/spidev0.0)
-s --speed    最大速度 (Hz)
-d --delay    延迟 (usec)
-b --bits     每字位数
-l --loop     回环测试
-H --cpha     时钟相位
-O --cpol     时钟极性
-L --lsb      LSB优先
-C --cs-high  片选高电平有效
-3 --3wire    SI/SO信号共享
-v --verbose  详细输出
-n --iterations 测试迭代次数
```

### SPI模式说明

| 模式 | CPOL | CPHA | 描述 |
|------|------|------|------|
| 0    | 0    | 0    | 空闲时时钟为低，第一个边沿采样 |
| 1    | 0    | 1    | 空闲时时钟为低，第二个边沿采样 |
| 2    | 1    | 0    | 空闲时时钟为高，第一个边沿采样 |
| 3    | 1    | 1    | 空闲时时钟为高，第二个边沿采样 |

### 测试结果

- `basic-test.txt` - 基础传输测试
- `loopback-test.txt` - 回环测试结果
- `speed-test.txt` - 速度测试数据
- `bits-test.txt` - 数据位测试
- `mode-test.txt` - SPI模式测试
- `stress-test.txt` - 压力测试
- `summary.txt` - 测试总结

## GPIO测试

### 功能特性

- GPIO芯片自动检测
- sysfs接口测试
- libgpiod工具测试
- GPIO读写操作
- GPIO翻转性能测试
- 中断监控
- 批量GPIO扫描

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install gpiod

# RHEL/CentOS
sudo yum install libgpiod-utils

# Fedora
sudo dnf install libgpiod-utils
```

### 运行测试

```bash
cd gpio/scripts
sudo ./test_gpio.sh
```

### 手动测试（sysfs接口）

```bash
# 导出GPIO17
echo 17 > /sys/class/gpio/export

# 设置为输出
echo out > /sys/class/gpio/gpio17/direction

# 写入高电平
echo 1 > /sys/class/gpio/gpio17/value

# 读取状态
cat /sys/class/gpio/gpio17/value

# 设置为输入
echo in > /sys/class/gpio/gpio17/direction

# 设置中断触发
echo both > /sys/class/gpio/gpio17/edge  # none, rising, falling, both

# 取消导出
echo 17 > /sys/class/gpio/unexport
```

### 手动测试（libgpiod工具）

```bash
# 检测GPIO芯片
gpiodetect

# 查看GPIO信息
gpioinfo gpiochip0

# 设置GPIO17为高电平
gpioset gpiochip0 17=1

# 设置GPIO17为低电平
gpioset gpiochip0 17=0

# 读取GPIO17状态
gpioget gpiochip0 17

# 监控GPIO17中断
gpiomon gpiochip0 17
```

### 使用测试程序

```bash
# 编译
cd gpio/programs
gcc -o gpio_test gpio_test.c

# 导出GPIO
sudo ./gpio_test -g 17 -o export

# 设置为输出
sudo ./gpio_test -g 17 -d out

# 写入高电平
sudo ./gpio_test -g 17 -o write -v 1

# 读取状态
sudo ./gpio_test -g 17 -o read

# 翻转测试
sudo ./gpio_test -g 17 -o toggle

# 监控中断（需要先设置edge）
sudo ./gpio_test -g 17 -e both -o monitor -t 10

# 取消导出
sudo ./gpio_test -g 17 -o unexport
```

### 测试结果

- `gpio-chips.txt` - GPIO芯片信息
- `gpio-info.txt` - GPIO详细信息
- `readwrite-test.txt` - 读写测试结果
- `toggle-test.txt` - 翻转性能测试
- `libgpiod-test.txt` - libgpiod工具测试
- `gpio-scan.txt` - GPIO可用性扫描
- `summary.txt` - 测试总结

## 故障排查

### I2C问题

**问题：未发现I2C总线**

```bash
# 检查I2C驱动
lsmod | grep i2c

# 查看内核日志
dmesg | grep i2c

# 加载驱动
sudo modprobe i2c-dev
```

**问题：设备访问被拒绝**

```bash
# 检查权限
ls -l /dev/i2c-*

# 添加用户到i2c组
sudo usermod -a -G i2c $USER

# 或修改设备权限
sudo chmod 666 /dev/i2c-*
```

### SPI问题

**问题：设备不存在**

```bash
# 检查SPI驱动
lsmod | grep spi

# 加载spidev
sudo modprobe spidev

# 检查设备树
ls -l /sys/bus/spi/devices/
```

**问题：传输失败**

```bash
# 检查连接
# 降低速度
sudo ./spidev_test -D /dev/spidev0.0 -s 100000

# 检查权限
sudo chmod 666 /dev/spidev0.0
```

### GPIO问题

**问题：GPIO不可用**

```bash
# 检查GPIO子系统
ls /sys/class/gpio/

# 查看内核配置
zcat /proc/config.gz | grep GPIO

# 检查设备树
ls /sys/firmware/devicetree/base/gpio*
```

**问题：权限不足**

```bash
# 使用sudo运行
sudo ./gpio_test -g 17 -o export

# 或修改udev规则
echo 'SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"' | sudo tee /etc/udev/rules.d/99-gpio.rules
sudo udevadm control --reload-rules
```

**问题：GPIO已被占用**

```bash
# 检查占用情况
cat /sys/kernel/debug/gpio

# 或使用libgpiod
gpioinfo gpiochip0 | grep -i used

# 释放GPIO
echo 17 > /sys/class/gpio/unexport
```

## 最佳实践

### I2C设备

1. **总线速度**：根据设备规格选择适当速度（标准100KHz，快速400KHz）
2. **上拉电阻**：确保SDA和SCL有适当的上拉电阻（通常4.7KΩ）
3. **地址冲突**：避免同一总线上的地址冲突
4. **错误处理**：实现重试机制处理传输错误

### SPI设备

1. **信号完整性**：使用短连接线，添加地线
2. **速度匹配**：不要超过设备支持的最大速度
3. **模式选择**：根据设备规格选择正确的SPI模式
4. **片选管理**：确保片选时序正确

### GPIO操作

1. **方向设置**：使用前明确设置为输入或输出
2. **中断去抖**：软件或硬件去抖处理
3. **电平兼容**：确保电压电平匹配（3.3V/5V）
4. **资源释放**：使用完毕后及时unexport

## 性能基准

### I2C典型性能

- 标准模式：100 Kbit/s
- 快速模式：400 Kbit/s
- 快速模式+：1 Mbit/s
- 高速模式：3.4 Mbit/s

### SPI典型性能

- 低速：< 1 MHz
- 中速：1-10 MHz
- 高速：10-50 MHz
- 超高速：> 50 MHz

### GPIO典型性能

- sysfs切换：< 100 Hz
- libgpiod切换：1-10 KHz
- 内核驱动切换：> 100 KHz

## 参考资料

- [I2C规范](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- [SPI总线协议](https://www.analog.com/en/analog-dialogue/articles/introduction-to-spi-interface.html)
- [Linux GPIO子系统](https://www.kernel.org/doc/html/latest/driver-api/gpio/index.html)
- [libgpiod文档](https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git/about/)

---

**更新日期：** 2026-04-19
**版本：** 1.0
