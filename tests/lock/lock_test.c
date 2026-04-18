/*
 * lock_test.c - 锁竞争和性能测试程序
 *
 * 用途: 测试多线程环境下的锁竞争、死锁检测和性能分析
 *
 * 编译: gcc -o lock_test lock_test.c -O2 -pthread
 * 运行: perf lock record ./lock_test
 *       perf lock report
 *
 * 作者: Linux Performance Testing Suite
 * 日期: 2026-04-18
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <sys/time.h>

#define MAX_THREADS 8
#define DEFAULT_THREADS 4
#define DEFAULT_ITERATIONS 100000
#define SHARED_COUNTER_COUNT 4

/* 测试类型 */
typedef enum {
    TEST_SINGLE_LOCK = 1,      /* 单个锁竞争 */
    TEST_MULTIPLE_LOCKS,       /* 多个锁 */
    TEST_LOCK_CHAIN,           /* 锁链（可能死锁） */
    TEST_READ_WRITE_LOCK,      /* 读写锁 */
    TEST_ALL
} test_type_t;

/* 共享数据 */
typedef struct {
    pthread_mutex_t lock;
    long counter;
    long contentions;
} shared_counter_t;

/* 全局变量 */
static shared_counter_t counters[SHARED_COUNTER_COUNT];
static pthread_rwlock_t rwlock;
static long read_count = 0;
static long write_count = 0;

/* 测试配置 */
static int num_threads = DEFAULT_THREADS;
static long iterations = DEFAULT_ITERATIONS;
static test_type_t test_type = TEST_ALL;

/*
 * 获取当前时间（微秒）
 */
static inline double get_time_us(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec * 1000000.0 + (double)tv.tv_usec;
}

/*
 * 初始化锁和计数器
 */
void init_locks(void) {
    int i;

    for (i = 0; i < SHARED_COUNTER_COUNT; i++) {
        pthread_mutex_init(&counters[i].lock, NULL);
        counters[i].counter = 0;
        counters[i].contentions = 0;
    }

    pthread_rwlock_init(&rwlock, NULL);
}

/*
 * 销毁锁
 */
void destroy_locks(void) {
    int i;

    for (i = 0; i < SHARED_COUNTER_COUNT; i++) {
        pthread_mutex_destroy(&counters[i].lock);
    }

    pthread_rwlock_destroy(&rwlock);
}

/*
 * 打印测试结果
 */
void print_results(const char *test_name, double elapsed_us, long total_ops) {
    printf("%-30s: %10ld ops in %10.2f ms -> %12.0f ops/sec\n",
           test_name,
           total_ops,
           elapsed_us / 1000.0,
           (double)total_ops / (elapsed_us / 1000000.0));
}

/* ========== 测试1: 单个锁竞争 ========== */

void *single_lock_worker(void *arg) {
    long i;
    (void)arg;  /* Unused */

    for (i = 0; i < iterations; i++) {
        pthread_mutex_lock(&counters[0].lock);
        counters[0].counter++;

        /* 模拟一些工作 */
        usleep(1);

        pthread_mutex_unlock(&counters[0].lock);
    }

    return NULL;
}

void test_single_lock(void) {
    pthread_t threads[MAX_THREADS];
    int i;
    double start, end;

    printf("\n[1/4] 测试单个锁竞争\n");
    printf("----------------------------------------\n");
    printf("说明: %d 个线程竞争同一个锁\n", num_threads);
    printf("预期: 高锁竞争，perf lock report 会显示等待时间\n\n");

    counters[0].counter = 0;

    start = get_time_us();

    /* 创建线程 */
    for (i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, single_lock_worker, (void *)(long)i);
    }

    /* 等待线程完成 */
    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    end = get_time_us();

    print_results("单锁竞争", end - start, counters[0].counter);
    printf("最终计数: %ld (期望: %ld)\n",
           counters[0].counter, (long)num_threads * iterations);
}

/* ========== 测试2: 多个独立锁 ========== */

void *multiple_locks_worker(void *arg) {
    long tid = (long)arg;
    long i;
    int lock_id;

    for (i = 0; i < iterations; i++) {
        /* 每个线程使用不同的锁 */
        lock_id = tid % SHARED_COUNTER_COUNT;

        pthread_mutex_lock(&counters[lock_id].lock);
        counters[lock_id].counter++;
        usleep(1);
        pthread_mutex_unlock(&counters[lock_id].lock);
    }

    return NULL;
}

void test_multiple_locks(void) {
    pthread_t threads[MAX_THREADS];
    int i;
    double start, end;
    long total = 0;

    printf("\n[2/4] 测试多个独立锁\n");
    printf("----------------------------------------\n");
    printf("说明: %d 个线程使用 %d 个不同的锁\n",
           num_threads, SHARED_COUNTER_COUNT);
    printf("预期: 较低锁竞争，更好的并发性能\n\n");

    /* 重置计数器 */
    for (i = 0; i < SHARED_COUNTER_COUNT; i++) {
        counters[i].counter = 0;
    }

    start = get_time_us();

    /* 创建线程 */
    for (i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, multiple_locks_worker, (void *)(long)i);
    }

    /* 等待线程完成 */
    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    end = get_time_us();

    /* 计算总数 */
    for (i = 0; i < SHARED_COUNTER_COUNT; i++) {
        total += counters[i].counter;
    }

    print_results("多锁并发", end - start, total);
    printf("各锁计数: ");
    for (i = 0; i < SHARED_COUNTER_COUNT; i++) {
        printf("[%d]=%ld ", i, counters[i].counter);
    }
    printf("\n");
}

/* ========== 测试3: 锁链（潜在死锁场景）========== */

void *lock_chain_worker(void *arg) {
    long i;
    (void)arg;  /* Unused */

    for (i = 0; i < iterations / 10; i++) {  /* 减少迭代避免太慢 */
        /* 按固定顺序获取多个锁，避免死锁 */
        pthread_mutex_lock(&counters[0].lock);
        pthread_mutex_lock(&counters[1].lock);

        counters[0].counter++;
        counters[1].counter++;
        usleep(1);

        pthread_mutex_unlock(&counters[1].lock);
        pthread_mutex_unlock(&counters[0].lock);
    }

    return NULL;
}

void test_lock_chain(void) {
    pthread_t threads[MAX_THREADS];
    int i;
    double start, end;

    printf("\n[3/4] 测试锁链（多锁顺序获取）\n");
    printf("----------------------------------------\n");
    printf("说明: 线程需要同时持有多个锁\n");
    printf("预期: 更高的锁等待时间\n\n");

    counters[0].counter = 0;
    counters[1].counter = 0;

    start = get_time_us();

    /* 创建线程 */
    for (i = 0; i < num_threads; i++) {
        pthread_create(&threads[i], NULL, lock_chain_worker, (void *)(long)i);
    }

    /* 等待线程完成 */
    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    end = get_time_us();

    print_results("锁链", end - start, counters[0].counter + counters[1].counter);
    printf("锁0计数: %ld, 锁1计数: %ld\n",
           counters[0].counter, counters[1].counter);
}

/* ========== 测试4: 读写锁 ========== */

void *reader_worker(void *arg) {
    long i;
    (void)arg;  /* Unused */

    for (i = 0; i < iterations; i++) {
        pthread_rwlock_rdlock(&rwlock);
        /* 模拟读操作 */
        usleep(1);
        pthread_rwlock_unlock(&rwlock);
    }

    return NULL;
}

void *writer_worker(void *arg) {
    long i;
    (void)arg;  /* Unused */

    for (i = 0; i < iterations / 10; i++) {  /* 写操作较少 */
        pthread_rwlock_wrlock(&rwlock);
        write_count++;
        usleep(10);  /* 写操作较慢 */
        pthread_rwlock_unlock(&rwlock);
    }

    return NULL;
}

void test_rwlock(void) {
    pthread_t readers[MAX_THREADS];
    pthread_t writers[MAX_THREADS / 2];
    int i;
    double start, end;
    int num_readers = num_threads;
    int num_writers = num_threads / 2;

    printf("\n[4/4] 测试读写锁\n");
    printf("----------------------------------------\n");
    printf("说明: %d 个读线程，%d 个写线程\n", num_readers, num_writers);
    printf("预期: 读锁可以并发，写锁互斥\n\n");

    read_count = 0;
    write_count = 0;

    start = get_time_us();

    /* 创建读线程 */
    for (i = 0; i < num_readers; i++) {
        pthread_create(&readers[i], NULL, reader_worker, (void *)(long)i);
    }

    /* 创建写线程 */
    for (i = 0; i < num_writers; i++) {
        pthread_create(&writers[i], NULL, writer_worker, (void *)(long)i);
    }

    /* 等待线程完成 */
    for (i = 0; i < num_readers; i++) {
        pthread_join(readers[i], NULL);
    }
    for (i = 0; i < num_writers; i++) {
        pthread_join(writers[i], NULL);
    }

    end = get_time_us();

    print_results("读写锁", end - start, (long)num_readers * iterations + write_count);
    printf("读操作: %ld, 写操作: %ld\n",
           (long)num_readers * iterations, write_count);
}

/*
 * 打印使用说明
 */
void print_usage(const char *prog) {
    printf("用法: %s [选项]\n\n", prog);
    printf("选项:\n");
    printf("  -t <type>    测试类型 (1-5, 默认: 5)\n");
    printf("               1 = 单个锁竞争\n");
    printf("               2 = 多个独立锁\n");
    printf("               3 = 锁链（多锁顺序获取）\n");
    printf("               4 = 读写锁\n");
    printf("               5 = 全部测试\n");
    printf("  -p <num>     线程数 (默认: %d)\n", DEFAULT_THREADS);
    printf("  -n <num>     每个线程的迭代次数 (默认: %d)\n", DEFAULT_ITERATIONS);
    printf("  -h           显示此帮助信息\n\n");
    printf("示例:\n");
    printf("  # 运行所有测试\n");
    printf("  %s\n\n", prog);
    printf("  # 只测试单锁竞争，8个线程\n");
    printf("  %s -t 1 -p 8\n\n", prog);
    printf("  # 使用 perf lock 分析\n");
    printf("  perf lock record %s\n", prog);
    printf("  perf lock report\n\n");
    printf("  # 查看锁统计\n");
    printf("  perf lock contention %s\n\n", prog);
}

/*
 * 主函数
 */
int main(int argc, char *argv[]) {
    int opt;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "t:p:n:h")) != -1) {
        switch (opt) {
            case 't':
                test_type = atoi(optarg);
                if (test_type < 1 || test_type > 5) {
                    fprintf(stderr, "错误: 测试类型必须是 1-5\n");
                    return 1;
                }
                break;
            case 'p':
                num_threads = atoi(optarg);
                if (num_threads < 1 || num_threads > MAX_THREADS) {
                    fprintf(stderr, "错误: 线程数必须在 1-%d 之间\n", MAX_THREADS);
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
    printf("║         Linux 锁性能和竞争测试                            ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("\n");
    printf("测试配置:\n");
    printf("  线程数: %d\n", num_threads);
    printf("  迭代次数: %ld\n", iterations);
    printf("  测试类型: ");
    switch (test_type) {
        case TEST_SINGLE_LOCK:      printf("单个锁竞争\n"); break;
        case TEST_MULTIPLE_LOCKS:   printf("多个独立锁\n"); break;
        case TEST_LOCK_CHAIN:       printf("锁链\n"); break;
        case TEST_READ_WRITE_LOCK:  printf("读写锁\n"); break;
        case TEST_ALL:              printf("全部测试\n"); break;
    }
    printf("\n");

    /* 初始化锁 */
    init_locks();

    /* 运行测试 */
    if (test_type == TEST_SINGLE_LOCK || test_type == TEST_ALL) {
        test_single_lock();
    }

    if (test_type == TEST_MULTIPLE_LOCKS || test_type == TEST_ALL) {
        test_multiple_locks();
    }

    if (test_type == TEST_LOCK_CHAIN || test_type == TEST_ALL) {
        test_lock_chain();
    }

    if (test_type == TEST_READ_WRITE_LOCK || test_type == TEST_ALL) {
        test_rwlock();
    }

    /* 清理 */
    destroy_locks();

    /* 打印总结 */
    printf("\n");
    printf("═══════════════════════════════════════════════════════════\n");
    printf("测试完成！\n");
    printf("\n");
    printf("使用 perf lock 分析锁竞争:\n");
    printf("  perf lock record %s\n", argv[0]);
    printf("  perf lock report\n");
    printf("\n");
    printf("实时锁竞争分析 (需要较新的 perf 版本):\n");
    printf("  perf lock contention %s\n", argv[0]);
    printf("═══════════════════════════════════════════════════════════\n");

    return 0;
}
