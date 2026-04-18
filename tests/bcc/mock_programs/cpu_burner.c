/*
 * cpu_burner.c - CPU 密集型模拟程序
 * 用于测试 profile 和 runqlat
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <math.h>

#define MAX_THREADS 8

typedef struct {
    int thread_id;
    long iterations;
} thread_arg_t;

// 计算密集型函数
void compute_intensive(long iterations) {
    long i;
    double result = 0.0;

    for (i = 0; i < iterations; i++) {
        result += sqrt(i) * sin(i) * cos(i);
    }

    // 防止编译器优化掉计算
    if (result < 0) {
        printf("Result: %f\n", result);
    }
}

void *worker_thread(void *arg) {
    thread_arg_t *targ = (thread_arg_t *)arg;

    printf("  线程 %d 启动，执行 %ld 次迭代...\n", targ->thread_id, targ->iterations);

    compute_intensive(targ->iterations);

    printf("  线程 %d 完成\n", targ->thread_id);

    return NULL;
}

int main(int argc, char *argv[]) {
    pthread_t threads[MAX_THREADS];
    thread_arg_t thread_args[MAX_THREADS];
    int num_threads = 4;
    long iterations = 10000000;  // 1000万次
    int i;

    if (argc > 1) {
        num_threads = atoi(argv[1]);
        if (num_threads > MAX_THREADS) {
            num_threads = MAX_THREADS;
        }
    }
    if (argc > 2) {
        iterations = atol(argv[2]);
    }

    printf("CPU Burner - CPU 密集型模拟程序\n");
    printf("线程数: %d\n", num_threads);
    printf("每线程迭代: %ld\n", iterations);
    printf("\n");

    printf("启动 %d 个 CPU 密集型线程...\n", num_threads);

    // 创建线程
    for (i = 0; i < num_threads; i++) {
        thread_args[i].thread_id = i;
        thread_args[i].iterations = iterations;

        if (pthread_create(&threads[i], NULL, worker_thread, &thread_args[i]) != 0) {
            perror("pthread_create");
            return 1;
        }
    }

    // 等待所有线程完成
    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    printf("\n完成！所有线程执行了 CPU 密集型计算\n");
    printf("总计算量: %ld 次迭代\n", iterations * num_threads);

    return 0;
}
