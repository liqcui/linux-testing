# SELinux 测试套件

## 概述

本测试套件提供了完整的SELinux测试工具，包括策略编译与加载、访问向量缓存(AVC)测试和多级安全(MLS/MCS)测试。

## 目录结构

```
selinux/
├── README.md                       # 本文件
├── policies/
│   ├── test_policy.te              # 测试策略模块
│   └── test_policy.fc              # 文件上下文定义
├── programs/
│   ├── test_selinux_prog.c         # SELinux测试程序
│   └── Makefile                    # 编译配置
├── scripts/
│   ├── test_policy_compile.sh      # 策略编译与加载测试
│   ├── test_avc.sh                 # AVC测试
│   └── test_mls.sh                 # MLS/MCS测试
└── results/                        # 测试结果目录
```

## 前置条件

### 安装依赖

**RHEL/CentOS/Fedora:**
```bash
sudo yum install policycoreutils policycoreutils-python-utils selinux-policy-devel audit libselinux-devel
```

**Ubuntu/Debian:**
```bash
sudo apt-get install policycoreutils selinux-utils selinux-policy-dev auditd libselinux1-dev
```

### 检查SELinux状态

```bash
# 查看SELinux状态
sestatus

# 查看当前模式
getenforce

# 查看当前上下文
id -Z
```

### 启用SELinux

如果SELinux未启用：

1. 编辑 `/etc/selinux/config`
2. 设置 `SELINUX=enforcing` 或 `SELINUX=permissive`
3. 重启系统

```bash
# 临时切换到permissive模式（不需要重启）
sudo setenforce 0

# 切换到enforcing模式
sudo setenforce 1
```

## 测试1: 策略编译与加载

### 功能特性

- 自动检测SELinux状态和工具
- 编译自定义策略模块
- 打包策略文件
- 加载和验证策略
- 策略卸载/重新加载测试
- 循环加载压力测试

### 运行测试

```bash
cd scripts
sudo ./test_policy_compile.sh
```

### 手动操作

#### 编译策略

```bash
cd policies

# 编译策略模块
checkmodule -M -m -o test_policy.mod test_policy.te

# 打包策略（包含文件上下文）
semodule_package -o test_policy.pp -m test_policy.mod -f test_policy.fc

# 或不包含文件上下文
semodule_package -o test_policy.pp -m test_policy.mod
```

#### 加载策略

```bash
# 安装/加载策略
sudo semodule -i test_policy.pp

# 验证策略已加载
semodule -l | grep test_policy

# 查看策略详情
semodule -l test_policy
```

#### 管理策略

```bash
# 卸载策略
sudo semodule -r test_policy

# 重新加载所有策略
sudo semodule -R

# 列出所有策略模块
semodule -l

# 禁用策略模块
sudo semodule -d test_policy

# 启用策略模块
sudo semodule -e test_policy
```

### 测试结果

- `selinux-status.txt` - SELinux状态信息
- `compile.log` - 编译日志
- `load.log` - 加载日志
- `modules.txt` - 已加载模块列表
- `summary.txt` - 测试总结

### 预期输出

```
========================================
SELinux策略编译与加载测试
========================================

步骤 1: 检查SELinux状态...
SELinux状态: enabled
当前模式: Enforcing

步骤 2: 检查策略编译工具...
✓ checkmodule: /usr/bin/checkmodule
✓ semodule_package: /usr/bin/semodule_package
✓ semodule: /usr/sbin/semodule

步骤 3: 编译测试策略...
✓ 编译成功: test_policy.mod
✓ 打包成功: test_policy.pp

步骤 4: 加载策略模块...
✓ 策略已加载

步骤 5: 验证策略...
✓ 策略模块已加载
```

## 测试2: AVC (访问向量缓存) 测试

### 功能特性

- AVC统计信息收集
- AVC查询性能测试
- 多文件访问缓存测试
- 上下文切换测试
- AVC拒绝检测和分析

### 运行测试

```bash
cd scripts
sudo ./test_avc.sh
```

### 手动操作

#### 查看AVC统计

```bash
# AVC统计路径（根据系统不同）
cat /sys/fs/selinux/avc/cache_stats
# 或
cat /selinux/avc/cache_stats
```

#### 清空缓存

```bash
# 注意：无法直接清空AVC缓存
# drop_caches只清空文件系统缓存，不影响AVC

# 清空文件系统缓存
echo 3 > /proc/sys/vm/drop_caches
```

#### 压力测试

```bash
# 大量不同主体的访问
for i in {1..1000}; do
    cat /etc/passwd > /dev/null 2>&1
done

# 查看AVC统计变化
cat /sys/fs/selinux/avc/cache_stats
```

#### 检查AVC拒绝

```bash
# 使用ausearch
ausearch -m avc -ts recent

# 使用ausearch查找特定时间
ausearch -m avc -ts today

# 从dmesg查找
dmesg | grep -i "avc.*denied"

# 查看审计日志
tail -f /var/log/audit/audit.log | grep AVC
```

### AVC统计说明

```
lookups   - 总查找次数
hits      - 缓存命中次数
misses    - 缓存未命中次数
allocations - 新条目分配次数
reclaims  - 条目回收次数
frees     - 条目释放次数
```

缓存命中率 = hits / lookups × 100%

### 测试结果

- `avc-initial.txt` - 初始AVC统计
- `avc-after-query.txt` - 查询测试后统计
- `avc-after-multifile.txt` - 多文件测试后统计
- `avc-after-context.txt` - 上下文切换后统计
- `avc-final.txt` - 最终统计
- `avc-analysis.txt` - 统计分析
- `context-switch.txt` - 上下文切换测试结果
- `avc-denials.txt` - AVC拒绝记录
- `summary.txt` - 测试总结

## 测试3: MLS/MCS (多级安全) 测试

### 功能特性

- MLS/MCS支持检测
- 文件类别设置
- runcon上下文切换测试
- 信息流控制验证
- 类别范围测试
- MLS相关AVC拒绝检查

### 运行测试

```bash
cd scripts
sudo ./test_mls.sh
```

### MLS vs MCS

**MLS (Multi-Level Security):**
- 完整的多级安全模型
- 支持安全级别(sensitivity levels)：s0, s1, s2...
- 支持类别(categories)：c0, c1, c2...
- 强制信息流控制
- 需要安装专门的MLS策略

**MCS (Multi-Category Security):**
- MLS的简化版本
- 仅支持类别，不支持多级别
- 所有进程在同一级别(s0)
- targeted策略默认支持
- 更易于管理和部署

### 手动操作

#### 创建不同安全级别的环境

```bash
# 低级别访问（类别c0）
runcon -l s0:c0 cat /tmp/low_data

# 中级别访问（类别c50）
runcon -l s0:c50 cat /tmp/medium_data

# 高级别访问（类别c100）
runcon -l s0:c100 cat /tmp/high_data

# 类别范围
runcon -l s0:c0.c50 cat /tmp/data
```

#### 设置文件类别

```bash
# 使用chcat工具
chcat -l -- +c0 /tmp/low_data
chcat -l -- +c50 /tmp/medium_data
chcat -l -- +c100 /tmp/high_data

# 查看文件上下文
ls -Z /tmp/*_data

# 删除类别
chcat -l -- -c0 /tmp/low_data
```

#### 验证信息流控制

```bash
# 测试"不上读"(No Read Up)
# 低级别进程不能读取高级别文件
runcon -l s0:c0 cat /tmp/high_data  # 应该失败

# 测试"不下写"(No Write Down)
# 高级别进程不能写入低级别文件
runcon -l s0:c100 sh -c "echo test >> /tmp/low_data"  # 应该失败

# 查看审计日志
ausearch -m avc -ts recent
dmesg | grep -i "avc: denied"
```

### 启用完整MLS策略

如果需要完整的MLS支持：

```bash
# 1. 安装MLS策略
sudo yum install selinux-policy-mls  # RHEL/CentOS/Fedora
sudo apt-get install selinux-policy-mls  # Ubuntu/Debian

# 2. 配置SELinux使用MLS策略
sudo vi /etc/selinux/config
# 设置: SELINUXTYPE=mls

# 3. 重新标记文件系统
sudo touch /.autorelabel

# 4. 重启系统
sudo reboot
```

### 测试结果

- `sestatus.txt` - SELinux详细状态
- `runcon-tests.txt` - runcon测试结果
- `mls-avc.txt` - MLS相关AVC记录
- `summary.txt` - 测试总结

## 测试程序

### 编译测试程序

```bash
cd programs
make

# 或手动编译
gcc -Wall -O2 -o test_selinux_prog test_selinux_prog.c -lselinux
```

### 运行测试程序

```bash
# 直接运行
./test_selinux_prog

# 以特定上下文运行
runcon -t unconfined_t ./test_selinux_prog

# 以特定级别运行
runcon -l s0:c0 ./test_selinux_prog
```

### 程序功能

- 检查SELinux启用状态
- 显示当前进程上下文
- 查询文件上下文
- 测试文件访问权限
- 测试进程操作（fork）

## 常见问题排查

### SELinux未启用

**现象：** `sestatus` 显示 "disabled"

**解决：**
```bash
# 1. 编辑配置
sudo vi /etc/selinux/config
# 设置: SELINUX=permissive

# 2. 重启系统
sudo reboot

# 3. 验证
getenforce  # 应该显示 Permissive
```

### 策略编译失败

**现象：** `checkmodule` 报错

**解决：**
```bash
# 检查策略语法
checkmodule -M -m -o /dev/null test_policy.te

# 查看详细错误
checkmodule -M -m -o test_policy.mod test_policy.te -v

# 安装策略开发包
sudo yum install selinux-policy-devel
```

### AVC拒绝过多

**现象：** 大量AVC denied消息

**解决：**
```bash
# 1. 切换到permissive模式调试
sudo setenforce 0

# 2. 查看拒绝详情
ausearch -m avc -ts recent

# 3. 生成策略建议
ausearch -m avc -ts recent | audit2allow -M mypolicy

# 4. 查看建议的策略
cat mypolicy.te

# 5. 安装策略
sudo semodule -i mypolicy.pp
```

### 无法查看AVC统计

**现象：** AVC统计文件不存在

**解决：**
```bash
# 检查selinuxfs挂载
mount | grep selinux

# 手动挂载
sudo mount -t selinuxfs none /sys/fs/selinux

# 或重启SELinux
sudo setenforce 0
sudo setenforce 1
```

### MLS测试失败

**现象：** runcon命令失败

**解决：**
```bash
# 1. 检查当前策略
sestatus | grep "Loaded policy"

# 2. 如果是targeted策略，只支持MCS
# 使用类别而不是级别
runcon -l s0:c0 cat /etc/passwd

# 3. 若需完整MLS，安装MLS策略
sudo yum install selinux-policy-mls
# 修改/etc/selinux/config为SELINUXTYPE=mls
# 重启系统
```

## SELinux上下文说明

SELinux上下文格式：`user:role:type:level`

### 用户 (User)
- `unconfined_u` - 未受限用户
- `system_u` - 系统用户
- `user_u` - 普通用户

### 角色 (Role)
- `unconfined_r` - 未受限角色
- `system_r` - 系统角色
- `user_r` - 用户角色

### 类型 (Type/Domain)
- `unconfined_t` - 未受限域
- `httpd_t` - Apache域
- `sshd_t` - SSH域

### 级别 (Level)
- `s0` - 最低级别
- `s0:c0` - 级别s0，类别c0
- `s0:c0.c50` - 级别s0，类别范围c0-c50
- `s0-s15:c0.c1023` - 完整MLS范围

## 最佳实践

1. **开发环境使用Permissive模式**
   ```bash
   sudo setenforce 0
   ```

2. **生产环境使用Enforcing模式**
   ```bash
   sudo setenforce 1
   ```

3. **定期审查AVC拒绝**
   ```bash
   ausearch -m avc -ts today | audit2allow -a
   ```

4. **使用布尔值调整策略**
   ```bash
   getsebool -a                    # 列出所有布尔值
   setsebool httpd_can_network_connect on  # 设置布尔值
   ```

5. **正确标记文件**
   ```bash
   restorecon -Rv /path/to/files   # 恢复文件上下文
   semanage fcontext -a -t httpd_sys_content_t "/web(/.*)?"  # 添加规则
   ```

## 性能考虑

### AVC缓存优化

- AVC缓存命中率应 > 95%
- 低命中率表明策略决策开销大
- 监控 `/sys/fs/selinux/avc/cache_stats`

### 策略大小

- 策略模块应尽可能小而专注
- 避免过度宽松的规则
- 定期清理未使用的策略

## 参考资料

- [SELinux Project](https://github.com/SELinuxProject)
- [Red Hat SELinux Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/using_selinux/)
- [SELinux Wiki](https://selinuxproject.org/page/Main_Page)
- [NSA SELinux Documentation](https://www.nsa.gov/What-We-Do/Research/SELinux/)

---

**更新日期：** 2026-04-19
**版本：** 1.0
