/*
 * interrupt_generator.c - 中断/信号生成器
 *
 * 生成定时信号以模拟中断场景，用于测试信号处理延迟
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>
#include <errno.h>

#define DEFAULT_INTERVAL_US 1000
#define DEFAULT_DURATION_S 60

/* 统计信息 */
static volatile unsigned long signal_count = 0;
static volatile unsigned long min_latency_ns = -1UL;
static volatile unsigned long max_latency_ns = 0;
static volatile unsigned long total_latency_ns = 0;

static struct timespec expected_time;
static unsigned long interval_ns;

/* 计算时间差（纳秒） */
static inline unsigned long timespec_diff_ns(struct timespec *start, struct timespec *end) {
    return (end->tv_sec - start->tv_sec) * 1000000000UL +
           (end->tv_nsec - start->tv_nsec);
}

/* 信号处理函数 */
static void signal_handler(int sig, siginfo_t *info, void *context) {
    struct timespec actual_time;
    unsigned long latency;

    (void)sig;
    (void)info;
    (void)context;

    /* 记录实际到达时间 */
    clock_gettime(CLOCK_MONOTONIC, &actual_time);

    /* 计算延迟 */
    latency = timespec_diff_ns(&expected_time, &actual_time);

    /* 更新统计 */
    signal_count++;
    total_latency_ns += latency;

    if (latency < min_latency_ns) {
        min_latency_ns = latency;
    }

    if (latency > max_latency_ns) {
        max_latency_ns = latency;
    }

    /* 计算下一次期望时间 */
    expected_time.tv_sec += interval_ns / 1000000000UL;
    expected_time.tv_nsec += interval_ns % 1000000000UL;

    if (expected_time.tv_nsec >= 1000000000UL) {
        expected_time.tv_sec++;
        expected_time.tv_nsec -= 1000000000UL;
    }
}

/* 定时器处理函数（POSIX 定时器） */
void timer_handler(union sigval sv) {
    struct timespec actual_time;
    unsigned long latency;

    (void)sv;

    /* 记录实际到达时间 */
    clock_gettime(CLOCK_MONOTONIC, &actual_time);

    /* 计算延迟 */
    latency = timespec_diff_ns(&expected_time, &actual_time);

    /* 更新统计 */
    signal_count++;
    total_latency_ns += latency;

    if (latency < min_latency_ns) {
        min_latency_ns = latency;
    }

    if (latency > max_latency_ns) {
        max_latency_ns = latency;
    }

    /* 计算下一次期望时间 */
    expected_time.tv_sec += interval_ns / 1000000000UL;
    expected_time.tv_nsec += interval_ns % 1000000000UL;

    if (expected_time.tv_nsec >= 1000000000UL) {
        expected_time.tv_sec++;
        expected_time.tv_nsec -= 1000000000UL;
    }
}

void print_usage(const char *prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -i USEC    Interval in microseconds (default: %d)\n", DEFAULT_INTERVAL_US);
    printf("  -d SEC     Duration in seconds (default: %d)\n", DEFAULT_DURATION_S);
    printf("  -m MODE    Mode: signal, timer, or itimer (default: timer)\n");
    printf("  -h         Show this help\n");
    printf("\nModes:\n");
    printf("  signal     Use POSIX signals (SIGRTMIN)\n");
    printf("  timer      Use POSIX timer (timer_create)\n");
    printf("  itimer     Use interval timer (setitimer)\n");
    printf("\nExample:\n");
    printf("  %s -i 1000 -d 60 -m timer\n", prog);
}

int main(int argc, char *argv[]) {
    int opt;
    int interval_us = DEFAULT_INTERVAL_US;
    int duration = DEFAULT_DURATION_S;
    char *mode = "timer";
    timer_t timerid;
    struct itimerspec its;
    struct sigevent sev;
    struct sigaction sa;
    struct itimerval itv;
    int elapsed = 0;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "i:d:m:h")) != -1) {
        switch (opt) {
        case 'i':
            interval_us = atoi(optarg);
            break;
        case 'd':
            duration = atoi(optarg);
            break;
        case 'm':
            mode = optarg;
            break;
        case 'h':
            print_usage(argv[0]);
            exit(0);
        default:
            print_usage(argv[0]);
            exit(1);
        }
    }

    interval_ns = interval_us * 1000UL;

    printf("Interrupt/Signal Generator\n");
    printf("======================================\n");
    printf("Mode:       %s\n", mode);
    printf("Interval:   %d μs\n", interval_us);
    printf("Duration:   %d seconds\n", duration);
    printf("======================================\n\n");

    /* 获取初始时间 */
    clock_gettime(CLOCK_MONOTONIC, &expected_time);

    if (strcmp(mode, "timer") == 0) {
        /* POSIX timer 模式 */
        printf("Using POSIX timer (timer_create)...\n\n");

        /* 配置定时器 */
        sev.sigev_notify = SIGEV_THREAD;
        sev.sigev_notify_function = timer_handler;
        sev.sigev_notify_attributes = NULL;
        sev.sigev_value.sival_ptr = NULL;

        if (timer_create(CLOCK_MONOTONIC, &sev, &timerid) < 0) {
            perror("timer_create");
            exit(1);
        }

        /* 设置定时器间隔 */
        its.it_value.tv_sec = 0;
        its.it_value.tv_nsec = interval_ns;
        its.it_interval.tv_sec = 0;
        its.it_interval.tv_nsec = interval_ns;

        if (timer_settime(timerid, 0, &its, NULL) < 0) {
            perror("timer_settime");
            exit(1);
        }

    } else if (strcmp(mode, "signal") == 0) {
        /* POSIX signal 模式 */
        printf("Using POSIX signals (SIGRTMIN)...\n\n");

        /* 设置信号处理 */
        sa.sa_flags = SA_SIGINFO;
        sa.sa_sigaction = signal_handler;
        sigemptyset(&sa.sa_mask);

        if (sigaction(SIGRTMIN, &sa, NULL) < 0) {
            perror("sigaction");
            exit(1);
        }

        /* 配置定时器（使用信号） */
        sev.sigev_notify = SIGEV_SIGNAL;
        sev.sigev_signo = SIGRTMIN;
        sev.sigev_value.sival_ptr = &timerid;

        if (timer_create(CLOCK_MONOTONIC, &sev, &timerid) < 0) {
            perror("timer_create");
            exit(1);
        }

        /* 设置定时器间隔 */
        its.it_value.tv_sec = 0;
        its.it_value.tv_nsec = interval_ns;
        its.it_interval.tv_sec = 0;
        its.it_interval.tv_nsec = interval_ns;

        if (timer_settime(timerid, 0, &its, NULL) < 0) {
            perror("timer_settime");
            exit(1);
        }

    } else if (strcmp(mode, "itimer") == 0) {
        /* 传统 interval timer 模式 */
        printf("Using interval timer (setitimer)...\n\n");

        /* 设置信号处理 */
        sa.sa_flags = SA_SIGINFO;
        sa.sa_sigaction = signal_handler;
        sigemptyset(&sa.sa_mask);

        if (sigaction(SIGALRM, &sa, NULL) < 0) {
            perror("sigaction");
            exit(1);
        }

        /* 设置间隔定时器 */
        itv.it_interval.tv_sec = interval_us / 1000000;
        itv.it_interval.tv_usec = interval_us % 1000000;
        itv.it_value.tv_sec = interval_us / 1000000;
        itv.it_value.tv_usec = interval_us % 1000000;

        if (setitimer(ITIMER_REAL, &itv, NULL) < 0) {
            perror("setitimer");
            exit(1);
        }

    } else {
        fprintf(stderr, "Unknown mode: %s\n", mode);
        exit(1);
    }

    /* 定期打印统计 */
    printf("Running...\n\n");

    while (elapsed < duration) {
        sleep(10);
        elapsed += 10;

        if (elapsed > duration) elapsed = duration;

        printf("[%3d s] Signals: %lu, Min: %lu ns, Avg: %lu ns, Max: %lu ns\n",
               elapsed,
               signal_count,
               min_latency_ns,
               signal_count > 0 ? total_latency_ns / signal_count : 0,
               max_latency_ns);
    }

    /* 停止定时器 */
    if (strcmp(mode, "itimer") == 0) {
        itv.it_value.tv_sec = 0;
        itv.it_value.tv_usec = 0;
        setitimer(ITIMER_REAL, &itv, NULL);
    } else {
        timer_delete(timerid);
    }

    /* 最终统计 */
    printf("\n======================================\n");
    printf("Final Statistics\n");
    printf("======================================\n");
    printf("Total signals:       %lu\n", signal_count);
    printf("Expected signals:    ~%lu\n", (duration * 1000000UL) / interval_us);
    printf("Min latency:         %lu ns (%.2f μs)\n",
           min_latency_ns, min_latency_ns / 1000.0);
    printf("Avg latency:         %lu ns (%.2f μs)\n",
           signal_count > 0 ? total_latency_ns / signal_count : 0,
           signal_count > 0 ? (total_latency_ns / signal_count) / 1000.0 : 0);
    printf("Max latency:         %lu ns (%.2f μs)\n",
           max_latency_ns, max_latency_ns / 1000.0);
    printf("======================================\n");

    return 0;
}
