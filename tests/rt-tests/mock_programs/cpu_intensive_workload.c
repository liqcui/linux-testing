/*
 * cpu_intensive_workload.c - CPU 密集型工作负载
 *
 * 用于测试调度器公平性和 CPU 分配
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>
#include <sys/types.h>

static volatile int running = 1;

void signal_handler(int sig) {
    (void)sig;
    running = 0;
}

/* CPU 密集型计算 - 质数计算 */
static int is_prime(unsigned long n) {
    if (n < 2) return 0;
    if (n == 2) return 1;
    if (n % 2 == 0) return 0;

    for (unsigned long i = 3; i * i <= n; i += 2) {
        if (n % i == 0) return 0;
    }
    return 1;
}

/* CPU 密集型计算 - 矩阵运算 */
static void matrix_multiply(int size) {
    double **a = malloc(size * sizeof(double *));
    double **b = malloc(size * sizeof(double *));
    double **c = malloc(size * sizeof(double *));

    for (int i = 0; i < size; i++) {
        a[i] = malloc(size * sizeof(double));
        b[i] = malloc(size * sizeof(double));
        c[i] = malloc(size * sizeof(double));

        for (int j = 0; j < size; j++) {
            a[i][j] = i + j;
            b[i][j] = i - j;
            c[i][j] = 0;
        }
    }

    /* 矩阵乘法 */
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            for (int k = 0; k < size; k++) {
                c[i][j] += a[i][k] * b[k][j];
            }
        }
    }

    /* 清理 */
    for (int i = 0; i < size; i++) {
        free(a[i]);
        free(b[i]);
        free(c[i]);
    }
    free(a);
    free(b);
    free(c);
}

void print_usage(const char *prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -d DURATION    运行时长（秒），默认：无限\n");
    printf("  -w WORKLOAD    工作负载类型：prime, matrix, mixed（默认：mixed）\n");
    printf("  -i INTENSITY   强度级别：1-10（默认：5）\n");
    printf("  -v             详细输出\n");
    printf("  -h             显示帮助\n");
    printf("\n");
    printf("示例:\n");
    printf("  %s -d 60 -w prime -i 7\n", prog);
    printf("  运行 60 秒的质数计算，强度级别 7\n");
}

int main(int argc, char *argv[]) {
    int duration = 0;  /* 0 表示无限运行 */
    char *workload = "mixed";
    int intensity = 5;
    int verbose = 0;
    int opt;

    /* 解析命令行参数 */
    while ((opt = getopt(argc, argv, "d:w:i:vh")) != -1) {
        switch (opt) {
        case 'd':
            duration = atoi(optarg);
            break;
        case 'w':
            workload = optarg;
            break;
        case 'i':
            intensity = atoi(optarg);
            if (intensity < 1) intensity = 1;
            if (intensity > 10) intensity = 10;
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

    /* 设置信号处理 */
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    printf("CPU Intensive Workload\n");
    printf("======================\n");
    printf("PID:       %d\n", getpid());
    printf("Workload:  %s\n", workload);
    printf("Intensity: %d/10\n", intensity);
    printf("Duration:  %s\n", duration > 0 ? "limited" : "infinite");
    printf("======================\n\n");

    if (verbose) {
        printf("Press Ctrl+C to stop\n\n");
    }

    /* 记录开始时间 */
    time_t start_time = time(NULL);
    unsigned long iterations = 0;
    unsigned long prime_count = 0;

    /* 根据强度调整工作量 */
    int matrix_size = 50 + (intensity * 10);
    unsigned long prime_range = 10000 * intensity;

    /* 主循环 */
    while (running) {
        /* 检查时间限制 */
        if (duration > 0) {
            time_t now = time(NULL);
            if (difftime(now, start_time) >= duration) {
                break;
            }
        }

        /* 执行工作负载 */
        if (strcmp(workload, "prime") == 0) {
            /* 质数计算 */
            for (unsigned long n = 2; n < prime_range && running; n++) {
                if (is_prime(n)) {
                    prime_count++;
                }
            }
        } else if (strcmp(workload, "matrix") == 0) {
            /* 矩阵运算 */
            matrix_multiply(matrix_size);
        } else {
            /* 混合工作负载 */
            if (iterations % 2 == 0) {
                matrix_multiply(matrix_size / 2);
            } else {
                for (unsigned long n = 2; n < prime_range / 2 && running; n++) {
                    if (is_prime(n)) {
                        prime_count++;
                    }
                }
            }
        }

        iterations++;

        /* 定期输出进度 */
        if (verbose && iterations % 10 == 0) {
            time_t now = time(NULL);
            printf("[%5lu s] Iterations: %lu, Primes: %lu\n",
                   (unsigned long)difftime(now, start_time),
                   iterations,
                   prime_count);
        }
    }

    /* 输出最终统计 */
    time_t end_time = time(NULL);
    unsigned long elapsed = (unsigned long)difftime(end_time, start_time);

    printf("\n");
    printf("======================\n");
    printf("Statistics\n");
    printf("======================\n");
    printf("Runtime:    %lu seconds\n", elapsed);
    printf("Iterations: %lu\n", iterations);
    if (strcmp(workload, "prime") == 0 || strcmp(workload, "mixed") == 0) {
        printf("Primes:     %lu\n", prime_count);
    }
    if (elapsed > 0) {
        printf("Iter/sec:   %.2f\n", (double)iterations / elapsed);
    }
    printf("======================\n");

    return 0;
}
