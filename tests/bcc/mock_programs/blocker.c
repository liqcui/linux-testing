/*
 * blocker.c - 阻塞操作模拟程序
 * 用于测试 offcputime
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>

#define MAX_THREADS 8

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;

typedef struct {
    int thread_id;
    int sleep_ms;
    int use_mutex;
    int use_io;
} thread_arg_t;

void *worker_thread(void *arg) {
    thread_arg_t *targ = (thread_arg_t *)arg;
    int i;

    printf("  线程 %d 启动\n", targ->thread_id);

    for (i = 0; i < 5; i++) {
        // 1. Sleep 阻塞
        if (targ->sleep_ms > 0) {
            printf("    [线程 %d] Sleep %d ms\n", targ->thread_id, targ->sleep_ms);
            usleep(targ->sleep_ms * 1000);
        }

        // 2. 互斥锁阻塞
        if (targ->use_mutex) {
            printf("    [线程 %d] 获取互斥锁\n", targ->thread_id);
            pthread_mutex_lock(&mutex);
            usleep(100000);  // 持锁 100ms
            pthread_mutex_unlock(&mutex);
        }

        // 3. I/O 阻塞
        if (targ->use_io) {
            char buffer[1024];
            FILE *fp;

            printf("    [线程 %d] 执行 I/O 操作\n", targ->thread_id);

            fp = fopen("/tmp/blocker_test.txt", "w");
            if (fp) {
                fwrite(buffer, 1, sizeof(buffer), fp);
                fsync(fileno(fp));  // 强制刷新到磁盘
                fclose(fp);
            }

            fp = fopen("/tmp/blocker_test.txt", "r");
            if (fp) {
                fread(buffer, 1, sizeof(buffer), fp);
                fclose(fp);
            }
        }
    }

    printf("  线程 %d 完成\n", targ->thread_id);

    return NULL;
}

int main(int argc, char *argv[]) {
    pthread_t threads[MAX_THREADS];
    thread_arg_t thread_args[MAX_THREADS];
    int num_threads = 4;
    int sleep_ms = 500;
    int i;

    if (argc > 1) {
        num_threads = atoi(argv[1]);
        if (num_threads > MAX_THREADS) {
            num_threads = MAX_THREADS;
        }
    }
    if (argc > 2) {
        sleep_ms = atoi(argv[2]);
    }

    printf("Blocker - 阻塞操作模拟程序\n");
    printf("线程数: %d\n", num_threads);
    printf("Sleep 时间: %d ms\n", sleep_ms);
    printf("\n");

    printf("启动 %d 个阻塞测试线程...\n", num_threads);
    printf("每个线程将执行:\n");
    printf("  - Sleep 阻塞\n");
    printf("  - 互斥锁竞争\n");
    printf("  - I/O 等待\n\n");

    // 创建线程
    for (i = 0; i < num_threads; i++) {
        thread_args[i].thread_id = i;
        thread_args[i].sleep_ms = sleep_ms;
        thread_args[i].use_mutex = 1;
        thread_args[i].use_io = 1;

        if (pthread_create(&threads[i], NULL, worker_thread, &thread_args[i]) != 0) {
            perror("pthread_create");
            return 1;
        }
    }

    // 等待所有线程完成
    for (i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    // 清理
    unlink("/tmp/blocker_test.txt");

    printf("\n完成！所有线程执行了阻塞操作\n");

    return 0;
}
