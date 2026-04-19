/*
 * realtime_task.c - 实时任务模拟
 *
 * 模拟周期性实时任务，用于测试 RT 调度器
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>
#include <signal.h>
#include <sys/mman.h>
#include <errno.h>

#define DEFAULT_PERIOD_US 10000   /* 10ms 周期 */
#define DEFAULT_RUNTIME_US 2000   /* 2ms 运行时间 */

static volatile int running = 1;

/* 统计信息 */
struct rt_stats {
    unsigned long cycles;
    unsigned long missed_deadlines;
    unsigned long min_latency_ns;
    unsigned long max_latency_ns;
    unsigned long total_latency_ns;
};

void signal_handler(int sig) {
    (void)sig;
    running = 0;
}

/* 纳秒级时间差 */
static inline unsigned long timespec_diff_ns(struct timespec *start, struct timespec *end) {
    return (end->tv_sec - start->tv_sec) * 1000000000UL +
           (end->tv_nsec - start->tv_nsec);
}

/* 繁忙等待指定纳秒 */
static void busy_wait_ns(unsigned long ns) {
    struct timespec start, now;
    unsigned long elapsed;

    clock_gettime(CLOCK_MONOTONIC, &start);

    do {
        volatile unsigned long counter = 0;
        for (int i = 0; i < 1000; i++) {
            counter++;
        }

        clock_gettime(CLOCK_MONOTONIC, &now);
        elapsed = timespec_diff_ns(&start, &now);
    } while (elapsed < ns);
}

void print_usage(const char *prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -p PERIOD      周期（微秒），默认：%d\n", DEFAULT_PERIOD_US);
    printf("  -r RUNTIME     运行时间（微秒），默认：%d\n", DEFAULT_RUNTIME_US);
    printf("  -d DURATION    测试时长（秒），默认：60\n");
    printf("  -s POLICY      调度策略：fifo, rr（默认：fifo）\n");
    printf("  -P PRIO        优先级（1-99），默认：80\n");
    printf("  -v             详细输出\n");
    printf("  -h             显示帮助\n");
    printf("\n");
    printf("注意：需要 root 权限设置实时优先级\n");
    printf("\n");
    printf("示例:\n");
    printf("  sudo %s -p 10000 -r 2000 -s fifo -P 90 -d 60\n", prog);
    printf("  周期 10ms, 运行时间 2ms, SCHED_FIFO, 优先级 90, 持续 60 秒\n");
}

int main(int argc, char *argv[]) {
    unsigned long period_us = DEFAULT_PERIOD_US;
    unsigned long runtime_us = DEFAULT_RUNTIME_US;
    int duration = 60;
    int policy = SCHED_FIFO;
    int priority = 80;
    int verbose = 0;
    int opt;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "p:r:d:s:P:vh")) != -1) {
        switch (opt) {
        case 'p':
            period_us = strtoul(optarg, NULL, 10);
            break;
        case 'r':
            runtime_us = strtoul(optarg, NULL, 10);
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
                fprintf(stderr, "Invalid policy: %s\n", optarg);
                exit(1);
            }
            break;
        case 'P':
            priority = atoi(optarg);
            if (priority < 1 || priority > 99) {
                fprintf(stderr, "Priority must be 1-99\n");
                exit(1);
            }
            break;
        case 'v':
            verbose = 1;
            break;
        case 'h':
            print_usage(argv[0]);
            exit(0);
        default:
            print_usage(argv[0]);
            exit(1);
        }
    }

    /* 验证参数 */
    if (runtime_us >= period_us) {
        fprintf(stderr, "Error: runtime must be less than period\n");
        exit(1);
    }

    printf("Real-Time Task Simulator\n");
    printf("========================\n");
    printf("PID:       %d\n", getpid());
    printf("Policy:    %s\n", policy == SCHED_FIFO ? "SCHED_FIFO" : "SCHED_RR");
    printf("Priority:  %d\n", priority);
    printf("Period:    %lu μs\n", period_us);
    printf("Runtime:   %lu μs\n", runtime_us);
    printf("Util:      %.1f%%\n", (double)runtime_us * 100 / period_us);
    printf("Duration:  %d seconds\n", duration);
    printf("========================\n\n");

    /* 设置信号处理 */
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    /* 锁定内存 */
    if (mlockall(MCL_CURRENT | MCL_FUTURE) < 0) {
        perror("mlockall");
        fprintf(stderr, "Warning: Cannot lock memory (may need root)\n");
    }

    /* 预分配栈 */
    char stack[8192];
    memset(stack, 0, sizeof(stack));

    /* 设置实时调度 */
    struct sched_param param;
    param.sched_priority = priority;

    if (sched_setscheduler(0, policy, &param) < 0) {
        perror("sched_setscheduler");
        fprintf(stderr, "Error: Cannot set RT priority (need root)\n");
        fprintf(stderr, "Running with normal priority instead\n");
    } else {
        printf("✓ Real-time scheduling enabled\n");
    }

    /* 获取实际调度信息 */
    int actual_policy = sched_getscheduler(0);
    sched_getparam(0, &param);
    printf("Actual policy: %d, priority: %d\n\n",
           actual_policy, param.sched_priority);

    /* 初始化统计 */
    struct rt_stats stats;
    stats.cycles = 0;
    stats.missed_deadlines = 0;
    stats.min_latency_ns = -1UL;
    stats.max_latency_ns = 0;
    stats.total_latency_ns = 0;

    /* 计算周期和运行时间（纳秒） */
    unsigned long period_ns = period_us * 1000;
    unsigned long runtime_ns = runtime_us * 1000;

    /* 获取开始时间 */
    struct timespec start_time, next_period, wakeup, end_time;
    clock_gettime(CLOCK_MONOTONIC, &start_time);

    next_period = start_time;

    printf("Starting periodic execution...\n\n");

    /* 周期性执行 */
    while (running) {
        /* 等待下一个周期 */
        clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next_period, NULL);

        /* 记录唤醒时间 */
        clock_gettime(CLOCK_MONOTONIC, &wakeup);

        /* 计算延迟 */
        unsigned long latency_ns = timespec_diff_ns(&next_period, &wakeup);

        /* 更新统计 */
        stats.cycles++;
        stats.total_latency_ns += latency_ns;

        if (latency_ns < stats.min_latency_ns) {
            stats.min_latency_ns = latency_ns;
        }

        if (latency_ns > stats.max_latency_ns) {
            stats.max_latency_ns = latency_ns;
        }

        /* 检查是否错过截止时间 */
        if (latency_ns > period_ns / 2) {
            stats.missed_deadlines++;
            if (verbose) {
                printf("! Missed deadline: latency = %lu μs\n",
                       latency_ns / 1000);
            }
        }

        /* 执行工作负载 */
        busy_wait_ns(runtime_ns);

        /* 详细输出 */
        if (verbose && stats.cycles % 100 == 0) {
            printf("[%5lu] Latency: %4lu μs, Avg: %4lu μs, Max: %4lu μs, Missed: %lu\n",
                   stats.cycles,
                   latency_ns / 1000,
                   stats.total_latency_ns / stats.cycles / 1000,
                   stats.max_latency_ns / 1000,
                   stats.missed_deadlines);
        }

        /* 计算下一个周期 */
        next_period.tv_sec += period_ns / 1000000000UL;
        next_period.tv_nsec += period_ns % 1000000000UL;

        if (next_period.tv_nsec >= 1000000000UL) {
            next_period.tv_sec++;
            next_period.tv_nsec -= 1000000000UL;
        }

        /* 检查时间限制 */
        clock_gettime(CLOCK_MONOTONIC, &end_time);
        if (timespec_diff_ns(&start_time, &end_time) / 1000000000UL >= duration) {
            break;
        }
    }

    /* 最终统计 */
    clock_gettime(CLOCK_MONOTONIC, &end_time);
    unsigned long total_time_s = timespec_diff_ns(&start_time, &end_time) / 1000000000UL;

    printf("\n");
    printf("========================\n");
    printf("Final Statistics\n");
    printf("========================\n");
    printf("Total time:          %lu seconds\n", total_time_s);
    printf("Total cycles:        %lu\n", stats.cycles);
    printf("Missed deadlines:    %lu (%.2f%%)\n",
           stats.missed_deadlines,
           stats.cycles > 0 ? (stats.missed_deadlines * 100.0 / stats.cycles) : 0);
    printf("Min latency:         %lu μs\n", stats.min_latency_ns / 1000);
    printf("Avg latency:         %lu μs\n",
           stats.cycles > 0 ? stats.total_latency_ns / stats.cycles / 1000 : 0);
    printf("Max latency:         %lu μs\n", stats.max_latency_ns / 1000);
    printf("========================\n");

    /* 性能评估 */
    unsigned long max_latency_us = stats.max_latency_ns / 1000;
    if (max_latency_us < 100) {
        printf("Performance: ★★★ Excellent\n");
    } else if (max_latency_us < 500) {
        printf("Performance: ★★☆ Good\n");
    } else if (max_latency_us < 1000) {
        printf("Performance: ★☆☆ Acceptable\n");
    } else {
        printf("Performance: ☆☆☆ Poor - needs tuning\n");
    }

    if (stats.missed_deadlines > 0) {
        printf("\nWarning: %lu deadlines missed!\n", stats.missed_deadlines);
        printf("Consider:\n");
        printf("  - Reducing CPU utilization\n");
        printf("  - Increasing priority\n");
        printf("  - Using CPU isolation\n");
        printf("  - Installing PREEMPT_RT kernel\n");
    }

    return 0;
}
