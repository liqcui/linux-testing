/*
 * cpu_hog.c - CPU密集型程序用于cgroup CPU测试
 *
 * 可配置线程数和运行时间
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>
#include <string.h>

static volatile int running = 1;
static long iterations = 0;

static void sigint_handler(int sig)
{
    (void)sig;
    running = 0;
}

static void *cpu_intensive_thread(void *arg)
{
    int thread_id = *(int *)arg;
    long local_iterations = 0;
    unsigned long long result = 1;

    printf("线程 %d 启动\n", thread_id);

    while (running) {
        // CPU密集计算：计算斐波那契数列
        for (int i = 0; i < 100000; i++) {
            result = (result * 1103515245 + 12345) & 0x7fffffff;
        }
        local_iterations++;

        // 每100万次迭代输出一次
        if (local_iterations % 1000 == 0) {
            __sync_fetch_and_add(&iterations, 1000);
        }
    }

    printf("线程 %d 停止，迭代次数: %ld\n", thread_id, local_iterations);
    return NULL;
}

int main(int argc, char *argv[])
{
    int num_threads = 1;
    int duration = 0;  // 0表示无限运行
    pthread_t *threads;
    int *thread_ids;
    struct timeval start, end;
    double elapsed;

    if (argc > 1) {
        num_threads = atoi(argv[1]);
    }
    if (argc > 2) {
        duration = atoi(argv[2]);
    }

    if (num_threads < 1 || num_threads > 64) {
        fprintf(stderr, "线程数必须在1-64之间\n");
        return 1;
    }

    printf("========================================\n");
    printf("CPU密集型测试程序\n");
    printf("========================================\n");
    printf("线程数: %d\n", num_threads);
    printf("持续时间: %s\n", duration > 0 ? "有限" : "无限（Ctrl+C停止）");
    if (duration > 0) {
        printf("运行时间: %d 秒\n", duration);
    }
    printf("进程PID: %d\n", getpid());
    printf("========================================\n\n");

    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    threads = malloc(num_threads * sizeof(pthread_t));
    thread_ids = malloc(num_threads * sizeof(int));

    if (!threads || !thread_ids) {
        fprintf(stderr, "内存分配失败\n");
        return 1;
    }

    gettimeofday(&start, NULL);

    // 创建线程
    for (int i = 0; i < num_threads; i++) {
        thread_ids[i] = i;
        if (pthread_create(&threads[i], NULL, cpu_intensive_thread, &thread_ids[i]) != 0) {
            fprintf(stderr, "创建线程 %d 失败\n", i);
            running = 0;
            break;
        }
    }

    // 如果指定了持续时间，则定时停止
    if (duration > 0) {
        sleep(duration);
        running = 0;
    } else {
        // 否则等待信号
        while (running) {
            sleep(1);
            printf("运行中... 总迭代: %ld k\n", iterations);
        }
    }

    printf("\n停止所有线程...\n");

    // 等待所有线程结束
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    gettimeofday(&end, NULL);
    elapsed = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0;

    printf("\n========================================\n");
    printf("测试完成\n");
    printf("========================================\n");
    printf("运行时间: %.2f 秒\n", elapsed);
    printf("总迭代: %ld k\n", iterations);
    printf("平均速率: %.2f k迭代/秒\n", iterations / elapsed);
    printf("========================================\n");

    free(threads);
    free(thread_ids);

    return 0;
}
