# Linux Testing Suite - Comprehensive Test Summary Report

**Generated:** 2026-04-19
**Project:** linux-testing
**Total Test Suites:** 34
**Coverage:** Performance, Functionality, Security, Real-time, Virtualization

---

## Executive Summary

This comprehensive Linux testing suite contains **34 specialized test suites** covering all major aspects of Linux system testing, from low-level kernel performance to high-level application scenarios. The suite integrates industry-standard tools and provides automated testing with detailed performance analysis and optimization recommendations.

### Coverage Overview

| Category | Test Suites | Key Focus Areas |
|----------|-------------|-----------------|
| **Performance Analysis** | 12 | CPU, Memory, I/O, Network throughput |
| **Kernel Tracing** | 4 | eBPF, BCC, bpftrace, perf |
| **Real-time Systems** | 1 | Latency, scheduling, SMI detection |
| **Benchmarking** | 6 | UnixBench, lmbench, STREAM, FIO |
| **Functionality Testing** | 6 | LTP, cgroup, namespace, security |
| **Virtualization** | 2 | KVM, kernel modules |
| **Specialized Testing** | 3 | Device drivers, memory analysis, locks |

---

## 1. eBPF and Kernel Tracing (4 Suites)

### 1.1 BCC (BPF Compiler Collection)
**Location:** `tests/bcc/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Process execution tracing (execsnoop)
- File operations tracing (opensnoop)
- Disk I/O tracing (biosnoop)
- TCP connection tracking (tcpconnect, tcpaccept)
- CPU profiling (profile)
- Memory leak detection (memleak)

**Key Features:**
- Mock programs for automated testing
- Python-based test framework
- Environment validation (check_bcc.sh)

**Quick Start:**
```bash
cd tests/bcc
sudo ./setup/install-bcc.sh
sudo ./check_bcc.sh
sudo python3 test_execsnoop.py
```

---

### 1.2 bpftrace
**Location:** `tests/bpftrace/`
**Status:** ✓ Complete with README

**Test Coverage:**
- System call statistics (syscall_count.bt)
- Kernel function latency analysis (function_latency.bt)
- TCP connection lifecycle (tcp_lifecycle.bt)
- Memory allocation tracking (memory_alloc.bt)
- Process lifecycle monitoring (process_lifecycle.bt)
- VFS I/O operations (vfs_io.bt)

**Key Features:**
- 6 comprehensive bpftrace scripts
- Mock programs for testing
- Automated test runner (run_all_tests.sh)
- Environment validation

**Quick Start:**
```bash
cd tests/bpftrace
sudo ./install_bpftrace.sh
sudo ./check_bpftrace.sh
sudo ./run_all_tests.sh
```

---

### 1.3 eBPF Comprehensive Suite
**Location:** `tests/ebpf/`
**Status:** ✓ Complete with README

**Test Coverage:**
- XDP (eXpress Data Path) programs
- TC (Traffic Control) eBPF programs
- Tracepoint programs
- Kprobe/Kretprobe programs
- Performance monitoring
- Network packet filtering

**Key Features:**
- Complete eBPF program examples
- Load and verification scripts
- Performance benchmarks

**Quick Start:**
```bash
cd tests/ebpf
sudo ./test_ebpf.sh
```

---

### 1.4 perf (Linux Performance Analysis)
**Location:** `tests/perf/`
**Status:** ✓ Complete with README

**Test Coverage:**
- CPU performance profiling
- Cache miss analysis
- Branch prediction analysis
- Memory access patterns
- Hardware event monitoring
- Software event tracing

**Key Features:**
- perf record/report workflows
- Flame graph generation
- Event filtering and analysis

**Quick Start:**
```bash
cd tests/perf
sudo ./test_perf.sh
```

---

## 2. Real-time Performance Testing (1 Suite)

### 2.1 rt-tests (Real-time Performance)
**Location:** `tests/rt-tests/`
**Status:** ✓ Complete with comprehensive README

**Test Coverage:**

**Basic Tests:**
- cyclictest: System latency measurement (interrupt, scheduling)
- pi_stress: Priority inheritance testing
- deadline_test: SCHED_DEADLINE scheduler testing
- signaltest: Signal latency testing
- hackbench: Scheduler performance

**Advanced Test Suites (NEW):**

1. **cyclictest_rt_full.sh** - Complete real-time testing
   - Single-thread SCHED_FIFO priority 99 (baseline)
   - Multi-thread priority distribution (99, 80, 60, 40)
   - CPU affinity binding test (isolated CPU)
   - Scheduling policy comparison (FIFO vs RR vs OTHER)
   - SMI interrupt detection
   - Duration: ~20 minutes

2. **cyclictest_three_scenarios.sh** - Scenario comparison
   - Idle (baseline)
   - CPU full load
   - I/O pressure
   - Combined pressure
   - Duration: 15-20 minutes

3. **stress_cyclictest_integrated.sh** - Stress + real-time integration
   - CPU pressure (ackermann)
   - Memory pressure (80%)
   - I/O pressure (mixed)
   - Combined pressure
   - FFT algorithm pressure
   - Matrix computation pressure
   - Duration: ~30 minutes (6 scenarios × 5 min)

4. **adaptive_stress_rt_test.sh** - Dynamic pressure adjustment
   - Stepwise CPU load: 10%, 25%, 50%, 75%, 90%, 100%
   - CPU algorithm comparison: ackermann, fft, matrixprod, correlate, trig
   - Latency-pressure curve generation
   - Duration: ~10 minutes

**Visualization Tools:**
- generate_histogram.sh: SVG histogram from .hist files
- generate_comparison_plot.sh: Multi-scenario 2×2 comparison
- generate_cdf_plot.sh: CDF curves with percentile analysis

**Performance Ratings:**
- **Excellent (Hard real-time)**: Max latency < 50μs ★★★★★
- **Good (Soft real-time)**: Max latency < 100μs ★★★★☆
- **Acceptable (Near real-time)**: Max latency < 500μs ★★★☆☆
- **Poor (Non real-time)**: Max latency > 500μs ★★☆☆☆

**Key Features:**
- Comprehensive scheduling policy testing
- Multi-scenario performance comparison
- Professional SVG visualization (gnuplot)
- CDF analysis with P50/P90/P99/P99.9 percentiles
- SMI interrupt detection
- Detailed optimization recommendations

**Quick Start:**
```bash
cd tests/rt-tests/scripts

# Complete real-time testing
sudo ./cyclictest_rt_full.sh

# Three-scenario comparison
sudo ./cyclictest_three_scenarios.sh

# Stress + real-time integration
sudo ./stress_cyclictest_integrated.sh

# Dynamic pressure adjustment
sudo ./adaptive_stress_rt_test.sh

# Generate visualizations
./generate_histogram.sh ../results/scenario1_idle.hist idle.svg
./generate_comparison_plot.sh ../results/cyclictest_scenarios_*/
./generate_cdf_plot.sh ../results/cyclictest_scenarios_*/
```

**Output Example:**
```
Scenario Comparison Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scenario          Min(μs)   Avg(μs)   Max(μs)   Degradation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Idle (baseline)   2         8         45        1.00x
CPU load          3         12        78        1.73x
I/O pressure      2         15        124       2.76x
Combined          3         18        156       3.47x
```

---

## 3. System Stress Testing (1 Suite)

### 3.1 stress-ng (Specialized Subsystem Testing)
**Location:** `tests/stress-ng/`
**Status:** ✓ Complete with comprehensive README and INTERPRETATION_GUIDE

**Test Coverage:**

**Specialized Test Scripts (NEW):**

1. **test_memory.sh** - Memory subsystem (9 tests)
   - VM allocation pressure (all methods)
   - memcpy bandwidth (GB/sec measurement)
   - mmap page fault testing
   - bigheap hugepage performance
   - malloc allocator testing
   - NUMA memory access (local vs remote)
   - memory comprehensive stress
   - STREAM bandwidth benchmark
   - cache pressure testing
   - Duration: ~9 minutes

2. **test_network.sh** - Network subsystem (9 tests)
   - TCP Socket pressure
   - UDP Socket pressure
   - Unix Domain Socket
   - socketpair IPC
   - netdev throughput
   - TCP connection flood
   - UDP packet flood
   - ICMP Echo pressure
   - sendfile zero-copy
   - Duration: ~9 minutes

3. **test_filesystem.sh** - Filesystem (10 tests)
   - HDD write throughput
   - I/O comprehensive (IOPS)
   - sync-file (fsync latency)
   - dir metadata operations
   - flock file locking
   - dentry cache
   - seek random access
   - readahead prefetch
   - aio async I/O
   - fallocate preallocation
   - Duration: ~10 minutes

**Performance Ratings:**

**Memory:**
- VM allocation: > 2000 ops/s ★★★★★ Excellent
- memcpy bandwidth: > 15 GB/s ★★★★★ Excellent (DDR4-3200)
- mmap page faults: < 1000/s ★★★★★ Excellent

**Network:**
- TCP Socket: > 100K ops/s ★★★★★ Excellent
- UDP Socket: > 150K ops/s ★★★★★ Excellent
- Unix Socket: > 200K ops/s ★★★★★ Excellent

**Filesystem:**
- NVMe SSD write: > 2000 MB/s ★★★★★ Excellent
- SATA SSD write: > 500 MB/s ★★★★★ Excellent
- HDD write: > 150 MB/s ★★★★★ Excellent

**INTERPRETATION_GUIDE.md** (500+ lines):
- Basic concepts (bogo ops, time metrics)
- Memory test interpretation (bandwidth, page faults, NUMA)
- Network test interpretation (protocols, throughput, packet loss)
- Filesystem test interpretation (storage types, I/O scheduler)
- Performance optimization recommendations

**Quick Start:**
```bash
cd tests/stress-ng/scripts

# Memory subsystem testing
sudo ./test_memory.sh

# Network subsystem testing
sudo ./test_network.sh

# Filesystem testing
sudo ./test_filesystem.sh

# Custom test path
sudo TEST_MOUNT=/data ./test_filesystem.sh

# View interpretation guide
cat ../INTERPRETATION_GUIDE.md
```

**Output Example:**
```
Memory Subsystem Test Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Item                 bogo ops/s (real)    Rating
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VM allocation             2183.45              ★★★★★ Excellent
memcpy bandwidth          5845.32              ★★★★★ Excellent
  • Bandwidth: 15.8 GB/sec
mmap                      7234.56              ★★★★★ Excellent
```

---

## 4. Network Performance Benchmarking (3 Suites)

### 4.1 iperf3
**Location:** `tests/iperf3/`
**Status:** ✓ Complete with README

**Test Coverage:**
- TCP throughput testing
- UDP throughput testing
- Bidirectional testing
- Multiple parallel streams
- JSON output format

**Performance Metrics:**
- Bandwidth (Gbps/Mbps)
- Jitter (UDP)
- Packet loss (UDP)
- Retransmissions (TCP)

**Quick Start:**
```bash
cd tests/iperf3
sudo ./test_iperf3.sh
```

---

### 4.2 netperf
**Location:** `tests/netperf/`
**Status:** ✓ Complete with README

**Test Coverage:**
- TCP_STREAM (bulk throughput)
- TCP_RR (request-response)
- TCP_CRR (connect-request-response)
- UDP_STREAM
- UDP_RR

**Performance Metrics:**
- Throughput (Mbps)
- Transactions per second
- Latency (microseconds)

**Quick Start:**
```bash
cd tests/netperf
sudo ./test_netperf.sh
```

---

### 4.3 qperf
**Location:** `tests/qperf/`
**Status:** ✓ Complete with README

**Test Coverage:**
- RDMA bandwidth and latency
- TCP/UDP bandwidth
- Socket bandwidth
- Latency measurements

**Performance Metrics:**
- Bandwidth (GB/s for RDMA)
- Latency (microseconds)
- Message rate (msgs/s)

**Quick Start:**
```bash
cd tests/qperf
sudo ./test_qperf.sh
```

---

## 5. Disk I/O Benchmarking (3 Suites)

### 5.1 fio (Flexible I/O Tester)
**Location:** `tests/fio/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Sequential read/write
- Random read/write
- Mixed workloads
- Various block sizes (4K, 8K, 64K, 1M)
- Different I/O depths
- Direct I/O vs buffered I/O

**Performance Metrics:**
- IOPS (I/O operations per second)
- Bandwidth (MB/s)
- Latency (microseconds)
- CPU utilization

**Quick Start:**
```bash
cd tests/fio
sudo ./run_fio_tests.sh
```

---

### 5.2 iozone
**Location:** `tests/iozone/`
**Status:** ✓ Complete with README

**Test Coverage:**
- 13 test modes: write, read, re-write, re-read, random read/write
- File sizes: 64KB to 512MB
- Record sizes: 4KB to 16MB
- Filesystem throughput analysis

**Performance Metrics:**
- Throughput (KB/s)
- File operations performance
- Cache effects

**Quick Start:**
```bash
cd tests/iozone
sudo ./test_iozone.sh
```

---

### 5.3 lmbench (Micro-benchmarks)
**Location:** `tests/lmbench/`
**Status:** ✓ Complete with README

**Test Coverage:**
- I/O latency (file operations)
- Memory latency and bandwidth
- Context switch latency
- Process creation overhead
- Signal handling latency
- Pipe/TCP latency

**Performance Metrics:**
- Latency (microseconds/nanoseconds)
- Bandwidth (MB/s)
- Operations per second

**Quick Start:**
```bash
cd tests/lmbench
./run_lmbench.sh
```

---

## 6. Memory Performance Testing (3 Suites)

### 6.1 STREAM Benchmark
**Location:** `tests/stream/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Copy: a[i] = b[i]
- Scale: a[i] = q * b[i]
- Add: a[i] = b[i] + c[i]
- Triad: a[i] = b[i] + q * c[i]

**Performance Metrics:**
- Memory bandwidth (MB/s, GB/s)
- Best/average/minimum rates
- Memory type identification (DDR3/DDR4)

**Performance Ratings:**
- DDR4-3200: > 20 GB/s
- DDR4-2666: 15-20 GB/s
- DDR4-2400: 10-15 GB/s

**Quick Start:**
```bash
cd tests/stream
./run_stream.sh
```

---

### 6.2 memtester
**Location:** `tests/memtester/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Stuck address test
- Random value test
- XOR comparison
- SUB comparison
- MUL comparison
- DIV comparison
- OR comparison
- AND comparison
- Sequential increment
- Solid bits test
- Checkerboard test
- Block sequential test
- Walking ones/zeros

**Quick Start:**
```bash
cd tests/memtester
sudo ./test_memtester.sh
```

---

### 6.3 memory-analysis
**Location:** `tests/memory-analysis/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Memory usage analysis
- Memory leak detection
- Page fault analysis
- NUMA statistics
- Swap usage monitoring

**Quick Start:**
```bash
cd tests/memory-analysis
sudo ./analyze_memory.sh
```

---

## 7. System Comprehensive Benchmarking (3 Suites)

### 7.1 UnixBench
**Location:** `tests/unixbench/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Dhrystone (integer arithmetic)
- Whetstone (floating point)
- Execl Throughput
- File Copy (various sizes)
- Pipe Throughput
- Pipe-based Context Switching
- Process Creation
- Shell Scripts
- System Call Overhead

**Performance Metrics:**
- Single-CPU score
- Multi-CPU score
- Index scores (relative to baseline)

**Quick Start:**
```bash
cd tests/unixbench
./run_unixbench.sh
```

---

### 7.2 lmbench (already covered in I/O section)

---

### 7.3 stressapptest
**Location:** `tests/stressapptest/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Memory interface stress
- Disk interface stress
- Network interface stress
- CPU stress
- Hardware reliability testing

**Quick Start:**
```bash
cd tests/stressapptest
sudo ./test_stressapptest.sh
```

---

## 8. Linux Functionality Testing (6 Suites)

### 8.1 LTP (Linux Test Project)
**Location:** `tests/ltp/`
**Status:** ✓ Complete with README

**Test Coverage:**
- 6000+ test cases
- System calls testing
- Commands testing
- Filesystem testing
- Networking testing
- IPC testing
- Scheduler testing
- Memory management

**Quick Start:**
```bash
cd tests/ltp
sudo ./run_ltp.sh
```

---

### 8.2 cgroup
**Location:** `tests/cgroup/`
**Status:** ✓ Complete with README

**Test Coverage:**
- CPU resource control
- Memory resource control
- I/O resource control
- Device access control
- cgroup v1 and v2 testing

**Quick Start:**
```bash
cd tests/cgroup
sudo ./test_cgroup.sh
```

---

### 8.3 namespace
**Location:** `tests/namespace/`
**Status:** ✓ Complete with README

**Test Coverage:**
- PID namespace
- Network namespace
- Mount namespace
- UTS namespace
- IPC namespace
- User namespace
- Cgroup namespace

**Quick Start:**
```bash
cd tests/namespace
sudo ./test_namespace.sh
```

---

### 8.4 security
**Location:** `tests/security/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Capabilities testing
- Seccomp filtering
- AppArmor profiles
- Privilege escalation tests
- File permissions

**Quick Start:**
```bash
cd tests/security
sudo ./test_security.sh
```

---

### 8.5 selinux
**Location:** `tests/selinux/`
**Status:** ✓ Complete with README

**Test Coverage:**
- SELinux policy enforcement
- Context transitions
- File labeling
- Process contexts
- Boolean toggles

**Quick Start:**
```bash
cd tests/selinux
sudo ./test_selinux.sh
```

---

## 9. Virtualization and Kernel Development (3 Suites)

### 9.1 KVM
**Location:** `tests/kvm/`
**Status:** ✓ Complete with README

**Test Coverage:**
- KVM module testing
- Virtual machine creation
- CPU virtualization
- Memory virtualization
- I/O virtualization
- Performance benchmarking

**Quick Start:**
```bash
cd tests/kvm
sudo ./test_kvm.sh
```

---

### 9.2 kernel-module
**Location:** `tests/kernel-module/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Module compilation
- Module loading/unloading
- Module parameters
- Module dependencies
- Kernel API testing

**Quick Start:**
```bash
cd tests/kernel-module
make && sudo ./load_module.sh
```

---

### 9.3 device-drivers
**Location:** `tests/device-drivers/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Character device drivers
- Block device drivers
- Network device drivers
- Driver registration
- IOCTL operations

**Quick Start:**
```bash
cd tests/device-drivers
sudo ./test_drivers.sh
```

---

## 10. Legacy Performance Tests (4 Suites)

### 10.1 syscalls (System Call Performance)
**Location:** `tests/syscalls/`
**Status:** ✓ Complete with README

**Test Coverage:**
- System call latency
- System call throughput
- Frequently used syscalls (read, write, open, close)

---

### 10.2 lock (Lock Contention)
**Location:** `tests/lock/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Mutex performance
- Spinlock performance
- RWlock performance
- Lock contention scenarios

---

### 10.3 mem (Memory Access)
**Location:** `tests/mem/`
**Status:** ✓ Complete with README

**Test Coverage:**
- Memory access patterns
- Cache effects
- TLB effects

---

### 10.4 block (Block Device)
**Location:** `tests/block/`
**Status:** ⚠ Missing README

**Test Coverage:**
- Block I/O tracing
- Block layer performance

---

## 11. Network Protocol Testing (2 Suites)

### 11.1 network
**Location:** `tests/network/`
**Status:** ⚠ Missing README

**Test Coverage:**
- Network packet tracing
- Protocol stack analysis

---

### 11.2 packetdrill
**Location:** `tests/packetdrill/`
**Status:** ⚠ Missing README

**Test Coverage:**
- TCP state machine testing
- TCP options testing
- Protocol conformance

---

## 12. Scheduling Testing (1 Suite)

### 12.1 sched
**Location:** `tests/sched/`
**Status:** ⚠ Missing README

**Test Coverage:**
- Scheduler latency
- Scheduler fairness
- CPU scheduling policies

---

### 12.2 tcp
**Location:** `tests/tcp/`
**Status:** ⚠ Missing README

**Test Coverage:**
- TCP performance
- TCP congestion control
- TCP options

---

## Test Suite Statistics

### Documentation Coverage

| Status | Count | Percentage |
|--------|-------|------------|
| ✓ Complete with README | 28 | 82.4% |
| ⚠ Missing README | 6 | 17.6% |
| **Total** | **34** | **100%** |

**Missing READMEs:**
1. tests/block/
2. tests/network/
3. tests/packetdrill/
4. tests/sched/
5. tests/tcp/

### Test Categories Distribution

| Category | Count | Percentage |
|----------|-------|------------|
| Performance Benchmarking | 12 | 35.3% |
| Kernel Tracing & eBPF | 4 | 11.8% |
| Functionality Testing | 6 | 17.6% |
| Network Testing | 5 | 14.7% |
| I/O Testing | 3 | 8.8% |
| Virtualization & Kernel | 3 | 8.8% |
| Real-time | 1 | 2.9% |

### Feature Highlights

**Most Comprehensive Suites:**
1. **rt-tests**: 4 advanced test scripts, 3 visualization tools, comprehensive documentation
2. **stress-ng**: 3 specialized subsystem tests (28 total tests), 500+ line interpretation guide
3. **bpftrace**: 6 comprehensive scripts, automated testing framework
4. **LTP**: 6000+ test cases covering entire Linux kernel

**Best Documented:**
1. rt-tests (README.md + comprehensive script documentation)
2. stress-ng (README.md + INTERPRETATION_GUIDE.md)
3. bcc (README.md + setup scripts + mock programs)
4. bpftrace (README.md + detailed script documentation)

**Most Professional Tools:**
1. UnixBench (industry standard)
2. LTP (official Linux test project)
3. FIO (flexible I/O tester)
4. iperf3 (network benchmarking standard)

---

## Recommendations

### Immediate Actions

1. **Create missing READMEs** for:
   - tests/block/
   - tests/network/
   - tests/packetdrill/
   - tests/sched/
   - tests/tcp/

2. **Consolidate overlapping tests**:
   - Consider merging tests/network/ into tests/iperf3/ or tests/netperf/
   - Integrate tests/sched/ into tests/rt-tests/
   - Merge tests/tcp/ into tests/packetdrill/

### Enhancement Opportunities

1. **Add CI/CD Integration**:
   - GitHub Actions workflow for automated testing
   - Test result validation
   - Performance regression detection

2. **Create Test Reports**:
   - Automated HTML report generation
   - Performance trend graphs
   - Comparison with baseline

3. **Add Container Support**:
   - Docker images for test environments
   - Isolated test execution
   - Reproducible results

4. **Expand Visualization**:
   - More gnuplot/matplotlib visualizations
   - Interactive dashboards
   - Real-time monitoring

---

## Test Execution Guidelines

### Full Test Suite Execution

**Estimated Total Time:** 4-6 hours

**Recommended Order:**
1. Quick validation tests (5 min)
2. eBPF and tracing tests (30 min)
3. Network benchmarks (1 hour)
4. I/O benchmarks (1 hour)
5. Memory tests (30 min)
6. Real-time tests (1 hour)
7. stress-ng specialized tests (30 min)
8. Comprehensive benchmarks (1-2 hours)
9. Functionality tests (variable)

### Minimal Test Set

For quick validation (30 minutes):
1. UnixBench (10 min)
2. iperf3 (5 min)
3. fio (10 min)
4. STREAM (2 min)
5. cyclictest basic (3 min)

### Performance Baseline

For establishing system baseline (2 hours):
1. UnixBench
2. lmbench
3. STREAM
4. fio comprehensive
5. iperf3 full suite
6. cyclictest extended
7. stress-ng all subsystems

---

## Conclusion

This Linux testing suite represents a **comprehensive, professional-grade testing framework** with:

- ✅ **34 specialized test suites** covering all major Linux subsystems
- ✅ **28 fully documented** test suites with detailed READMEs
- ✅ **Industry-standard tools** (UnixBench, LTP, FIO, iperf3, etc.)
- ✅ **Advanced real-time testing** with visualization and CDF analysis
- ✅ **Specialized subsystem testing** with performance ratings and optimization guides
- ✅ **Modern kernel tracing** with eBPF, BCC, and bpftrace
- ✅ **Automated testing frameworks** for reproducible results

The suite is suitable for:
- **System administrators** evaluating hardware performance
- **Kernel developers** testing kernel modifications
- **Performance engineers** optimizing system configurations
- **QA teams** validating Linux distributions
- **Researchers** conducting performance studies
- **DevOps teams** establishing performance baselines

---

**Report Version:** 1.0
**Last Updated:** 2026-04-19
**Maintainer:** linux-testing project
**License:** MIT
