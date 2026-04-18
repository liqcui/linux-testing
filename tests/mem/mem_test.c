/*
 * mem_test.c - 内存访问性能测试程序
 *
 * 用途: 测试不同内存访问模式的性能和缓存行为
 *
 * 编译: gcc -o mem_test mem_test.c -O2 -pthread
 * 运行: perf mem record ./mem_test
 *       perf mem report
 *
 * 作者: Linux Performance Testing Suite
 * 日期: 2026-04-18
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/time.h>
#include <stdint.h>

#define MB (1024 * 1024)
#define KB (1024)
#define CACHE_LINE_SIZE 64

/* 默认配置 */
#define DEFAULT_SIZE (64 * MB)      /* 64MB 数组 */
#define DEFAULT_ITERATIONS 10       /* 迭代次数 */
#define DEFAULT_THREADS 4           /* 线程数 */

/* 测试类型 */
typedef enum {
    TEST_SEQUENTIAL_READ = 1,   /* 顺序读 */
    TEST_SEQUENTIAL_WRITE,      /* 顺序写 */
    TEST_RANDOM_READ,           /* 随机读 */
    TEST_RANDOM_WRITE,          /* 随机写 */
    TEST_STRIDE_READ,           /* 跨步读（跳过缓存行） */
    TEST_FALSE_SHARING,         /* 伪共享 */
    TEST_TRUE_SHARING,          /* 真共享 */
    TEST_ALL
} test_type_t;

/* 性能统计 */
typedef struct {
    const char *name;
    size_t bytes_accessed;
    double elapsed_time;
    double bandwidth_mbps;
} perf_stats_t;

/* 全局变量 */
static char *test_buffer = NULL;
static size_t buffer_size = DEFAULT_SIZE;
static int iterations = DEFAULT_ITERATIONS;
static int num_threads = DEFAULT_THREADS;
static test_type_t test_type = TEST_ALL;

/* 用于伪共享测试的结构 */
typedef struct {
    long counter;
    char padding[CACHE_LINE_SIZE - sizeof(long)];
} padded_counter_t;

static padded_counter_t *padded_counters = NULL;
static long *shared_counters = NULL;

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
    printf("%-30s: %8.2f MB accessed in %8.2f ms -> %10.2f MB/s\n",
           stats->name,
           (double)stats->bytes_accessed / MB,
           stats->elapsed_time / 1000.0,
           stats->bandwidth_mbps);
}

/*
 * 初始化测试缓冲区
 */
void init_buffer(void) {
    size_t i;

    test_buffer = (char *)malloc(buffer_size);
    if (!test_buffer) {
        perror("malloc");
        exit(1);
    }

    /* 初始化为随机数据 */
    for (i = 0; i < buffer_size; i++) {
        test_buffer[i] = (char)(rand() % 256);
    }

    /* 为伪共享测试分配内存 */
    padded_counters = (padded_counter_t *)malloc(num_threads * sizeof(padded_counter_t));
    shared_counters = (long *)malloc(num_threads * sizeof(long));

    if (!padded_counters || !shared_counters) {
        perror("malloc");
        exit(1);
    }

    memset(padded_counters, 0, num_threads * sizeof(padded_counter_t));
    memset(shared_counters, 0, num_threads * sizeof(long));
}

/*
 * 清理测试缓冲区
 */
void cleanup_buffer(void) {
    free(test_buffer);
    free(padded_counters);
    free(shared_counters);
}

/* ========== 测试1: 顺序读 ========== */

void test_sequential_read(void) {
    double start, end;
    int iter;
    size_t i;
    volatile long sum = 0;
    perf_stats_t stats;

    printf("\n[1/7] 测试顺序读\n");
    printf("----------------------------------------\n");
    printf("说明: 按顺序读取内存，对缓存友好\n");
    printf("预期: 高带宽，低缓存未命中\n\n");

    start = get_time_us();

    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < buffer_size; i++) {
            sum += test_buffer[i];
        }
    }

    end = get_time_us();

    stats.name = "顺序读";
    stats.bytes_accessed = (size_t)iterations * buffer_size;
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);
    printf("校验和: %ld (防止编译器优化)\n", sum);
}

/* ========== 测试2: 顺序写 ========== */

void test_sequential_write(void) {
    double start, end;
    int iter;
    size_t i;
    perf_stats_t stats;

    printf("\n[2/7] 测试顺序写\n");
    printf("----------------------------------------\n");
    printf("说明: 按顺序写入内存\n");
    printf("预期: 高带宽，写合并优化\n\n");

    start = get_time_us();

    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < buffer_size; i++) {
            test_buffer[i] = (char)(i & 0xFF);
        }
    }

    end = get_time_us();

    stats.name = "顺序写";
    stats.bytes_accessed = (size_t)iterations * buffer_size;
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);
}

/* ========== 测试3: 随机读 ========== */

void test_random_read(void) {
    double start, end;
    int iter;
    size_t i;
    volatile long sum = 0;
    size_t *indices;
    perf_stats_t stats;
    size_t num_accesses = buffer_size / 64;  /* 减少访问次数 */

    printf("\n[3/7] 测试随机读\n");
    printf("----------------------------------------\n");
    printf("说明: 随机位置读取，缓存不友好\n");
    printf("预期: 低带宽，高缓存未命中\n\n");

    /* 预生成随机索引 */
    indices = (size_t *)malloc(num_accesses * sizeof(size_t));
    for (i = 0; i < num_accesses; i++) {
        indices[i] = (size_t)rand() % buffer_size;
    }

    start = get_time_us();

    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < num_accesses; i++) {
            sum += test_buffer[indices[i]];
        }
    }

    end = get_time_us();

    stats.name = "随机读";
    stats.bytes_accessed = (size_t)iterations * num_accesses;
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);
    printf("校验和: %ld\n", sum);

    free(indices);
}

/* ========== 测试4: 随机写 ========== */

void test_random_write(void) {
    double start, end;
    int iter;
    size_t i;
    size_t *indices;
    perf_stats_t stats;
    size_t num_accesses = buffer_size / 64;

    printf("\n[4/7] 测试随机写\n");
    printf("----------------------------------------\n");
    printf("说明: 随机位置写入\n");
    printf("预期: 低带宽，无法利用写合并\n\n");

    /* 预生成随机索引 */
    indices = (size_t *)malloc(num_accesses * sizeof(size_t));
    for (i = 0; i < num_accesses; i++) {
        indices[i] = (size_t)rand() % buffer_size;
    }

    start = get_time_us();

    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < num_accesses; i++) {
            test_buffer[indices[i]] = (char)(i & 0xFF);
        }
    }

    end = get_time_us();

    stats.name = "随机写";
    stats.bytes_accessed = (size_t)iterations * num_accesses;
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);

    free(indices);
}

/* ========== 测试5: 跨步读（跳过缓存行）========== */

void test_stride_read(void) {
    double start, end;
    int iter;
    size_t i;
    volatile long sum = 0;
    perf_stats_t stats;
    size_t stride = CACHE_LINE_SIZE;  /* 每次跳过一个缓存行 */

    printf("\n[5/7] 测试跨步读 (stride=%zu bytes)\n", stride);
    printf("----------------------------------------\n");
    printf("说明: 跳过缓存行读取，浪费缓存空间\n");
    printf("预期: 带宽低于顺序读\n\n");

    start = get_time_us();

    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < buffer_size; i += stride) {
            sum += test_buffer[i];
        }
    }

    end = get_time_us();

    stats.name = "跨步读";
    stats.bytes_accessed = (size_t)iterations * (buffer_size / stride);
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);
    printf("校验和: %ld\n", sum);
}

/* ========== 测试6: 伪共享（False Sharing）========== */

void *false_sharing_worker(void *arg) {
    long tid = (long)arg;
    int i;

    /* 多个线程写相邻的计数器（在同一缓存行） */
    for (i = 0; i < 10000000; i++) {
        shared_counters[tid]++;
    }

    return NULL;
}

void test_false_sharing(void) {
    pthread_t threads[16];
    int i;
    double start, end;
    perf_stats_t stats;

    printf("\n[6/7] 测试伪共享（False Sharing）\n");
    printf("----------------------------------------\n");
    printf("说明: 多线程写相邻内存（同一缓存行）\n");
    printf("预期: 缓存行颠簸，性能差\n\n");

    start = get_time_us();

    for (i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, false_sharing_worker, (void *)(long)i);
    }

    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    end = get_time_us();

    stats.name = "伪共享";
    stats.bytes_accessed = (size_t)num_threads * 10000000 * sizeof(long);
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);
    printf("计数器: ");
    for (i = 0; i < num_threads && i < 4; i++) {
        printf("[%d]=%ld ", i, shared_counters[i]);
    }
    printf("\n");
}

/* ========== 测试7: 无伪共享（True Sharing）========== */

void *no_false_sharing_worker(void *arg) {
    long tid = (long)arg;
    int i;

    /* 每个线程写独立的缓存行（有padding） */
    for (i = 0; i < 10000000; i++) {
        padded_counters[tid].counter++;
    }

    return NULL;
}

void test_no_false_sharing(void) {
    pthread_t threads[16];
    int i;
    double start, end;
    perf_stats_t stats;

    printf("\n[7/7] 测试无伪共享（带 Padding）\n");
    printf("----------------------------------------\n");
    printf("说明: 多线程写独立缓存行\n");
    printf("预期: 无缓存行颠簸，性能好\n\n");

    start = get_time_us();

    for (i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, no_false_sharing_worker, (void *)(long)i);
    }

    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    end = get_time_us();

    stats.name = "无伪共享";
    stats.bytes_accessed = (size_t)num_threads * 10000000 * sizeof(long);
    stats.elapsed_time = end - start;
    stats.bandwidth_mbps = (double)stats.bytes_accessed / (stats.elapsed_time / 1000000.0) / MB;

    print_stats(&stats);
    printf("计数器: ");
    for (i = 0; i < num_threads && i < 4; i++) {
        printf("[%d]=%ld ", i, padded_counters[i].counter);
    }
    printf("\n");
}

/*
 * 打印使用说明
 */
void print_usage(const char *prog) {
    printf("用法: %s [选项]\n\n", prog);
    printf("选项:\n");
    printf("  -t <type>    测试类型 (1-8, 默认: 8)\n");
    printf("               1 = 顺序读\n");
    printf("               2 = 顺序写\n");
    printf("               3 = 随机读\n");
    printf("               4 = 随机写\n");
    printf("               5 = 跨步读\n");
    printf("               6 = 伪共享\n");
    printf("               7 = 无伪共享\n");
    printf("               8 = 全部测试\n");
    printf("  -s <size>    缓冲区大小 MB (默认: 64)\n");
    printf("  -n <num>     迭代次数 (默认: %d)\n", DEFAULT_ITERATIONS);
    printf("  -p <num>     线程数 (默认: %d)\n", DEFAULT_THREADS);
    printf("  -h           显示此帮助信息\n\n");
    printf("示例:\n");
    printf("  # 运行所有测试\n");
    printf("  %s\n\n", prog);
    printf("  # 只测试顺序读，128MB缓冲区\n");
    printf("  %s -t 1 -s 128\n\n", prog);
    printf("  # 使用 perf mem 分析\n");
    printf("  perf mem record %s\n", prog);
    printf("  perf mem report\n\n");
    printf("  # 查看缓存统计\n");
    printf("  perf stat -e cache-references,cache-misses %s\n\n", prog);
}

/*
 * 主函数
 */
int main(int argc, char *argv[]) {
    int opt;
    int size_mb = 64;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "t:s:n:p:h")) != -1) {
        switch (opt) {
            case 't':
                test_type = atoi(optarg);
                if (test_type < 1 || test_type > 8) {
                    fprintf(stderr, "错误: 测试类型必须是 1-8\n");
                    return 1;
                }
                break;
            case 's':
                size_mb = atoi(optarg);
                if (size_mb <= 0 || size_mb > 4096) {
                    fprintf(stderr, "错误: 缓冲区大小必须在 1-4096 MB 之间\n");
                    return 1;
                }
                buffer_size = (size_t)size_mb * MB;
                break;
            case 'n':
                iterations = atoi(optarg);
                if (iterations <= 0) {
                    fprintf(stderr, "错误: 迭代次数必须 > 0\n");
                    return 1;
                }
                break;
            case 'p':
                num_threads = atoi(optarg);
                if (num_threads < 1 || num_threads > 16) {
                    fprintf(stderr, "错误: 线程数必须在 1-16 之间\n");
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
    printf("║         Linux 内存访问性能测试                            ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("\n");
    printf("测试配置:\n");
    printf("  缓冲区大小: %d MB\n", size_mb);
    printf("  迭代次数: %d\n", iterations);
    printf("  线程数: %d\n", num_threads);
    printf("  缓存行大小: %d bytes\n", CACHE_LINE_SIZE);
    printf("  测试类型: ");
    switch (test_type) {
        case TEST_SEQUENTIAL_READ:  printf("顺序读\n"); break;
        case TEST_SEQUENTIAL_WRITE: printf("顺序写\n"); break;
        case TEST_RANDOM_READ:      printf("随机读\n"); break;
        case TEST_RANDOM_WRITE:     printf("随机写\n"); break;
        case TEST_STRIDE_READ:      printf("跨步读\n"); break;
        case TEST_FALSE_SHARING:    printf("伪共享\n"); break;
        case TEST_TRUE_SHARING:     printf("无伪共享\n"); break;
        case TEST_ALL:              printf("全部测试\n"); break;
    }
    printf("\n");

    /* 初始化 */
    srand(time(NULL));
    init_buffer();

    /* 运行测试 */
    if (test_type == TEST_SEQUENTIAL_READ || test_type == TEST_ALL) {
        test_sequential_read();
    }

    if (test_type == TEST_SEQUENTIAL_WRITE || test_type == TEST_ALL) {
        test_sequential_write();
    }

    if (test_type == TEST_RANDOM_READ || test_type == TEST_ALL) {
        test_random_read();
    }

    if (test_type == TEST_RANDOM_WRITE || test_type == TEST_ALL) {
        test_random_write();
    }

    if (test_type == TEST_STRIDE_READ || test_type == TEST_ALL) {
        test_stride_read();
    }

    if (test_type == TEST_FALSE_SHARING || test_type == TEST_ALL) {
        test_false_sharing();
    }

    if (test_type == TEST_TRUE_SHARING || test_type == TEST_ALL) {
        test_no_false_sharing();
    }

    /* 清理 */
    cleanup_buffer();

    /* 打印总结 */
    printf("\n");
    printf("═══════════════════════════════════════════════════════════\n");
    printf("测试完成！\n");
    printf("\n");
    printf("使用 perf mem 分析内存访问:\n");
    printf("  perf mem record %s\n", argv[0]);
    printf("  perf mem report\n");
    printf("\n");
    printf("查看缓存统计:\n");
    printf("  perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses %s\n", argv[0]);
    printf("═══════════════════════════════════════════════════════════\n");

    return 0;
}
