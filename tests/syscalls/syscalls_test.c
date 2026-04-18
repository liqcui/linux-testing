/*
 * syscalls_test.c - 系统调用性能测试程序
 *
 * 用途: 测试不同类型系统调用的性能开销
 *
 * 编译: gcc -o syscalls_test syscalls_test.c -O2
 * 运行: perf stat -e cycles -e instructions -e cache-misses ./syscalls_test
 *
 * 作者: Linux Performance Testing Suite
 * 日期: 2026-04-18
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>
#include <sys/time.h>
#include <errno.h>

#define ITERATIONS 1000000  /* 默认迭代次数 */
#define BUFFER_SIZE 4096

/* 测试选项 */
typedef enum {
    TEST_GETPID = 1,
    TEST_GETTIMEOFDAY,
    TEST_READ_WRITE,
    TEST_OPEN_CLOSE,
    TEST_STAT,
    TEST_ALL
} test_type_t;

/* 性能统计 */
typedef struct {
    const char *name;
    long iterations;
    double elapsed_time;
    double ops_per_sec;
} perf_stats_t;

/*
 * 获取当前时间（微秒）
 */
static inline double get_time_us(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec * 1000000.0 + (double)tv.tv_usec;
}

/*
 * 打印性能统计
 */
void print_stats(perf_stats_t *stats) {
    printf("%-20s: %10ld iterations in %10.2f ms -> %12.0f ops/sec\n",
           stats->name,
           stats->iterations,
           stats->elapsed_time / 1000.0,
           stats->ops_per_sec);
}

/*
 * 测试1: getpid() - 最简单的系统调用
 */
void test_getpid(long iterations) {
    double start, end;
    long i;
    pid_t pid;
    perf_stats_t stats;

    printf("\n[1/5] 测试 getpid() 系统调用\n");
    printf("----------------------------------------\n");
    printf("说明: getpid() 是最简单的系统调用之一，直接返回进程ID\n");
    printf("开销: 主要是用户态→内核态的切换开销\n\n");

    start = get_time_us();
    for (i = 0; i < iterations; i++) {
        pid = getpid();
    }
    end = get_time_us();

    stats.name = "getpid()";
    stats.iterations = iterations;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)iterations / (stats.elapsed_time / 1000000.0);

    print_stats(&stats);
    printf("最后一次PID: %d\n", pid);
}

/*
 * 测试2: gettimeofday() - 获取时间
 */
void test_gettimeofday(long iterations) {
    double start, end;
    long i;
    struct timeval tv;
    perf_stats_t stats;

    printf("\n[2/5] 测试 gettimeofday() 系统调用\n");
    printf("----------------------------------------\n");
    printf("说明: 获取当前时间，需要读取系统时钟\n");
    printf("开销: 比getpid()稍重，但通常有vDSO优化\n\n");

    start = get_time_us();
    for (i = 0; i < iterations; i++) {
        gettimeofday(&tv, NULL);
    }
    end = get_time_us();

    stats.name = "gettimeofday()";
    stats.iterations = iterations;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)iterations / (stats.elapsed_time / 1000000.0);

    print_stats(&stats);
}

/*
 * 测试3: read() / write() - 文件I/O
 */
void test_read_write(long iterations) {
    double start, end;
    long i;
    int fd;
    char buffer[BUFFER_SIZE];
    ssize_t bytes;
    perf_stats_t stats;

    printf("\n[3/5] 测试 read()/write() 系统调用\n");
    printf("----------------------------------------\n");
    printf("说明: 使用/dev/zero和/dev/null避免真实I/O\n");
    printf("开销: 系统调用 + 内核缓冲区操作\n\n");

    /* 准备 */
    memset(buffer, 0, BUFFER_SIZE);

    /* 测试 read() */
    fd = open("/dev/zero", O_RDONLY);
    if (fd < 0) {
        perror("open /dev/zero");
        return;
    }

    start = get_time_us();
    for (i = 0; i < iterations / 100; i++) {  /* 减少迭代次数避免太慢 */
        bytes = read(fd, buffer, BUFFER_SIZE);
        if (bytes < 0) {
            perror("read");
            break;
        }
    }
    end = get_time_us();
    close(fd);

    stats.name = "read()";
    stats.iterations = iterations / 100;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)stats.iterations / (stats.elapsed_time / 1000000.0);
    print_stats(&stats);

    /* 测试 write() */
    fd = open("/dev/null", O_WRONLY);
    if (fd < 0) {
        perror("open /dev/null");
        return;
    }

    start = get_time_us();
    for (i = 0; i < iterations / 100; i++) {
        bytes = write(fd, buffer, BUFFER_SIZE);
        if (bytes < 0) {
            perror("write");
            break;
        }
    }
    end = get_time_us();
    close(fd);

    stats.name = "write()";
    stats.iterations = iterations / 100;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)stats.iterations / (stats.elapsed_time / 1000000.0);
    print_stats(&stats);
}

/*
 * 测试4: open() / close() - 文件打开关闭
 */
void test_open_close(long iterations) {
    double start, end;
    long i;
    int fd;
    perf_stats_t stats;

    printf("\n[4/5] 测试 open()/close() 系统调用\n");
    printf("----------------------------------------\n");
    printf("说明: 打开和关闭/dev/null\n");
    printf("开销: 文件表操作 + 文件描述符分配\n\n");

    start = get_time_us();
    for (i = 0; i < iterations / 10; i++) {  /* 减少迭代次数 */
        fd = open("/dev/null", O_RDONLY);
        if (fd < 0) {
            perror("open");
            break;
        }
        close(fd);
    }
    end = get_time_us();

    stats.name = "open()+close()";
    stats.iterations = iterations / 10;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)stats.iterations / (stats.elapsed_time / 1000000.0);
    print_stats(&stats);
}

/*
 * 测试5: stat() - 获取文件信息
 */
void test_stat(long iterations) {
    double start, end;
    long i;
    struct stat st;
    int ret;
    perf_stats_t stats;

    printf("\n[5/5] 测试 stat() 系统调用\n");
    printf("----------------------------------------\n");
    printf("说明: 获取/dev/null的文件信息\n");
    printf("开销: 路径解析 + inode查找 + 元数据读取\n\n");

    start = get_time_us();
    for (i = 0; i < iterations / 10; i++) {
        ret = stat("/dev/null", &st);
        if (ret < 0) {
            perror("stat");
            break;
        }
    }
    end = get_time_us();

    stats.name = "stat()";
    stats.iterations = iterations / 10;
    stats.elapsed_time = end - start;
    stats.ops_per_sec = (double)stats.iterations / (stats.elapsed_time / 1000000.0);
    print_stats(&stats);
}

/*
 * 打印使用说明
 */
void print_usage(const char *prog) {
    printf("用法: %s [选项]\n\n", prog);
    printf("选项:\n");
    printf("  -t <type>    测试类型 (1-6, 默认: 6)\n");
    printf("               1 = getpid()\n");
    printf("               2 = gettimeofday()\n");
    printf("               3 = read()/write()\n");
    printf("               4 = open()/close()\n");
    printf("               5 = stat()\n");
    printf("               6 = 全部测试\n");
    printf("  -n <num>     迭代次数 (默认: %d)\n", ITERATIONS);
    printf("  -h           显示此帮助信息\n\n");
    printf("示例:\n");
    printf("  # 运行所有测试\n");
    printf("  %s\n\n", prog);
    printf("  # 只测试getpid，迭代10万次\n");
    printf("  %s -t 1 -n 100000\n\n", prog);
    printf("  # 使用perf分析\n");
    printf("  perf stat -e cycles -e instructions -e cache-misses %s\n\n", prog);
}

/*
 * 主函数
 */
int main(int argc, char *argv[]) {
    int opt;
    test_type_t test_type = TEST_ALL;
    long iterations = ITERATIONS;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "t:n:h")) != -1) {
        switch (opt) {
            case 't':
                test_type = atoi(optarg);
                if (test_type < 1 || test_type > 6) {
                    fprintf(stderr, "错误: 测试类型必须是 1-6\n");
                    return 1;
                }
                break;
            case 'n':
                iterations = atol(optarg);
                if (iterations <= 0) {
                    fprintf(stderr, "错误: 迭代次数必须 > 0\n");
                    return 1;
                }
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }

    /* 打印测试信息 */
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║         Linux 系统调用性能测试                            ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("\n");
    printf("测试配置:\n");
    printf("  迭代次数: %ld\n", iterations);
    printf("  测试类型: ");
    switch (test_type) {
        case TEST_GETPID:       printf("getpid()\n"); break;
        case TEST_GETTIMEOFDAY: printf("gettimeofday()\n"); break;
        case TEST_READ_WRITE:   printf("read()/write()\n"); break;
        case TEST_OPEN_CLOSE:   printf("open()/close()\n"); break;
        case TEST_STAT:         printf("stat()\n"); break;
        case TEST_ALL:          printf("全部测试\n"); break;
    }
    printf("\n");

    /* 运行测试 */
    if (test_type == TEST_GETPID || test_type == TEST_ALL) {
        test_getpid(iterations);
    }

    if (test_type == TEST_GETTIMEOFDAY || test_type == TEST_ALL) {
        test_gettimeofday(iterations);
    }

    if (test_type == TEST_READ_WRITE || test_type == TEST_ALL) {
        test_read_write(iterations);
    }

    if (test_type == TEST_OPEN_CLOSE || test_type == TEST_ALL) {
        test_open_close(iterations);
    }

    if (test_type == TEST_STAT || test_type == TEST_ALL) {
        test_stat(iterations);
    }

    /* 打印总结 */
    printf("\n");
    printf("═══════════════════════════════════════════════════════════\n");
    printf("测试完成！\n");
    printf("\n");
    printf("使用 perf 分析系统调用开销:\n");
    printf("  perf stat -e cycles -e instructions -e cache-misses %s\n", argv[0]);
    printf("\n");
    printf("使用 strace 跟踪系统调用:\n");
    printf("  strace -c %s\n", argv[0]);
    printf("═══════════════════════════════════════════════════════════\n");

    return 0;
}
