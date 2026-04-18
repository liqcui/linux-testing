/*
 * rt_workload.c - 实时工作负载模拟程序
 *
 * 模拟实时任务的周期性执行，用于验证实时调度和延迟
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>
#include <pthread.h>
#include <sys/mman.h>
#include <errno.h>

/* 默认参数 */
#define DEFAULT_PRIORITY 80
#define DEFAULT_INTERVAL_US 1000  /* 1ms */
#define DEFAULT_RUNTIME_US 100    /* 100μs */
#define DEFAULT_DURATION_S 60     /* 60 seconds */

/* 统计信息 */
struct stats {
    unsigned long iterations;
    unsigned long min_latency;
    unsigned long max_latency;
    unsigned long total_latency;
    unsigned long missed_deadlines;
};

/* 纳秒级时间差计算 */
static inline unsigned long timespec_diff_ns(struct timespec *start, struct timespec *end) {
    return (end->tv_sec - start->tv_sec) * 1000000000UL +
           (end->tv_nsec - start->tv_nsec);
}

/* 模拟工作负载 */
static void do_work(unsigned long runtime_ns) {
    struct timespec start, now;
    unsigned long elapsed;
    volatile unsigned long counter = 0;

    clock_gettime(CLOCK_MONOTONIC, &start);

    do {
        /* 执行一些计算 */
        counter++;

        /* 检查时间 */
        clock_gettime(CLOCK_MONOTONIC, &now);
        elapsed = timespec_diff_ns(&start, &now);
    } while (elapsed < runtime_ns);
}

/* 实时任务线程 */
static void *rt_task(void *arg) {
    struct stats *stats = (struct stats *)arg;
    struct timespec next_period, wakeup, period;
    unsigned long interval_ns = DEFAULT_INTERVAL_US * 1000;
    unsigned long runtime_ns = DEFAULT_RUNTIME_US * 1000;
    unsigned long latency_ns;

    /* 初始化统计 */
    stats->iterations = 0;
    stats->min_latency = -1UL;
    stats->max_latency = 0;
    stats->total_latency = 0;
    stats->missed_deadlines = 0;

    /* 获取当前时间并计算第一个周期 */
    clock_gettime(CLOCK_MONOTONIC, &next_period);

    period.tv_sec = interval_ns / 1000000000UL;
    period.tv_nsec = interval_ns % 1000000000UL;

    while (1) {
        /* 等待下一个周期 */
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next_period, NULL);

        /* 记录唤醒时间 */
        clock_gettime(CLOCK_MONOTONIC, &wakeup);

        /* 计算延迟 */
        latency_ns = timespec_diff_ns(&next_period, &wakeup);

        /* 更新统计 */
        stats->iterations++;
        stats->total_latency += latency_ns;

        if (latency_ns < stats->min_latency) {
            stats->min_latency = latency_ns;
        }

        if (latency_ns > stats->max_latency) {
            stats->max_latency = latency_ns;
        }

        /* 检查是否错过截止时间 */
        if (latency_ns > interval_ns / 2) {
            stats->missed_deadlines++;
        }

        /* 执行工作负载 */
        do_work(runtime_ns);

        /* 计算下一个周期 */
        next_period.tv_sec += period.tv_sec;
        next_period.tv_nsec += period.tv_nsec;

        if (next_period.tv_nsec >= 1000000000UL) {
            next_period.tv_sec++;
            next_period.tv_nsec -= 1000000000UL;
        }
    }

    return NULL;
}

void print_usage(const char *prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -p PRIO    Real-time priority (1-99, default: %d)\n", DEFAULT_PRIORITY);
    printf("  -i USEC    Interval in microseconds (default: %d)\n", DEFAULT_INTERVAL_US);
    printf("  -r USEC    Runtime in microseconds (default: %d)\n", DEFAULT_RUNTIME_US);
    printf("  -d SEC     Duration in seconds (default: %d)\n", DEFAULT_DURATION_S);
    printf("  -s POLICY  Scheduling policy (fifo/rr, default: fifo)\n");
    printf("  -h         Show this help\n");
    printf("\nExample:\n");
    printf("  %s -p 90 -i 1000 -r 100 -d 60\n", prog);
    printf("  Run with priority 90, 1ms interval, 100μs runtime, for 60 seconds\n");
}

int main(int argc, char *argv[]) {
    int priority = DEFAULT_PRIORITY;
    int policy = SCHED_FIFO;
    int duration = DEFAULT_DURATION_S;
    int opt;
    pthread_t thread;
    struct sched_param param;
    struct stats stats;
    struct timespec start_time, current_time;
    unsigned long elapsed_sec;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "p:i:r:d:s:h")) != -1) {
        switch (opt) {
        case 'p':
            priority = atoi(optarg);
            if (priority < 1 || priority > 99) {
                fprintf(stderr, "Invalid priority: %d (must be 1-99)\n", priority);
                exit(1);
            }
            break;
        case 'i':
            /* 间隔参数将在线程中使用 */
            break;
        case 'r':
            /* 运行时间参数将在线程中使用 */
            break;
        case 'd':
            duration = atoi(optarg);
            break;
        case 's':
            if (strcmp(optarg, "fifo") == 0) {
                policy = SCHED_FIFO;
            } else if (strcmp(optarg, "rr") == 0) {
                policy = SCHED_RR;
            } else {
                fprintf(stderr, "Invalid policy: %s (use fifo or rr)\n", optarg);
                exit(1);
            }
            break;
        case 'h':
            print_usage(argv[0]);
            exit(0);
        default:
            print_usage(argv[0]);
            exit(1);
        }
    }

    printf("Real-Time Workload Simulator\n");
    printf("======================================\n");
    printf("Priority:   %d\n", priority);
    printf("Policy:     %s\n", policy == SCHED_FIFO ? "SCHED_FIFO" : "SCHED_RR");
    printf("Interval:   %d μs\n", DEFAULT_INTERVAL_US);
    printf("Runtime:    %d μs\n", DEFAULT_RUNTIME_US);
    printf("Duration:   %d seconds\n", duration);
    printf("======================================\n\n");

    /* 锁定内存 */
    if (mlockall(MCL_CURRENT | MCL_FUTURE) < 0) {
        perror("mlockall");
        fprintf(stderr, "Warning: Cannot lock memory (may need root)\n");
    }

    /* 预分配栈 */
    char stack[8192];
    memset(stack, 0, sizeof(stack));

    /* 设置实时优先级 */
    param.sched_priority = priority;
    if (sched_setscheduler(0, policy, &param) < 0) {
        perror("sched_setscheduler");
        fprintf(stderr, "Error: Cannot set real-time priority (may need root)\n");
        exit(1);
    }

    printf("Starting real-time task...\n\n");

    /* 创建实时线程 */
    if (pthread_create(&thread, NULL, rt_task, &stats) != 0) {
        perror("pthread_create");
        exit(1);
    }

    /* 记录开始时间 */
    clock_gettime(CLOCK_MONOTONIC, &start_time);

    /* 定期打印统计信息 */
    while (1) {
        sleep(10);

        clock_gettime(CLOCK_MONOTONIC, &current_time);
        elapsed_sec = current_time.tv_sec - start_time.tv_sec;

        if (elapsed_sec >= duration) {
            break;
        }

        printf("[%3lu s] Iterations: %lu, Min: %lu ns, Avg: %lu ns, Max: %lu ns, Missed: %lu\n",
               elapsed_sec,
               stats.iterations,
               stats.min_latency,
               stats.iterations > 0 ? stats.total_latency / stats.iterations : 0,
               stats.max_latency,
               stats.missed_deadlines);
    }

    /* 最终统计 */
    printf("\n======================================\n");
    printf("Final Statistics\n");
    printf("======================================\n");
    printf("Total iterations:    %lu\n", stats.iterations);
    printf("Min latency:         %lu ns (%.2f μs)\n",
           stats.min_latency, stats.min_latency / 1000.0);
    printf("Avg latency:         %lu ns (%.2f μs)\n",
           stats.iterations > 0 ? stats.total_latency / stats.iterations : 0,
           stats.iterations > 0 ? (stats.total_latency / stats.iterations) / 1000.0 : 0);
    printf("Max latency:         %lu ns (%.2f μs)\n",
           stats.max_latency, stats.max_latency / 1000.0);
    printf("Missed deadlines:    %lu (%.2f%%)\n",
           stats.missed_deadlines,
           stats.iterations > 0 ? (stats.missed_deadlines * 100.0 / stats.iterations) : 0);
    printf("======================================\n");

    /* 评估 */
    if (stats.max_latency < 50000) {  /* < 50μs */
        printf("Performance: ★★★ Excellent\n");
    } else if (stats.max_latency < 100000) {  /* < 100μs */
        printf("Performance: ★★☆ Good\n");
    } else if (stats.max_latency < 200000) {  /* < 200μs */
        printf("Performance: ★☆☆ Acceptable\n");
    } else {
        printf("Performance: ☆☆☆ Needs optimization\n");
    }

    return 0;
}
