/*
 * lat_ctx.c - 上下文切换延迟测试
 * 测量进程/线程上下文切换的延迟
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sched.h>
#include <string.h>

#define ITERATIONS 10000

static inline double now(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec + (double)tv.tv_usec / 1000000.0;
}

/* 测试进程上下文切换 */
double test_process_ctx(int iterations, int datasize)
{
    int pipefd1[2], pipefd2[2];
    pid_t pid;
    char *buf;
    double start, end;
    int i;

    buf = malloc(datasize);
    if (!buf) {
        perror("malloc");
        return -1.0;
    }
    memset(buf, 'x', datasize);

    if (pipe(pipefd1) < 0 || pipe(pipefd2) < 0) {
        perror("pipe");
        free(buf);
        return -1.0;
    }

    pid = fork();
    if (pid < 0) {
        perror("fork");
        free(buf);
        return -1.0;
    }

    if (pid == 0) {
        /* 子进程 */
        close(pipefd1[1]);
        close(pipefd2[0]);

        for (i = 0; i < iterations; i++) {
            read(pipefd1[0], buf, datasize);
            write(pipefd2[1], buf, datasize);
        }

        close(pipefd1[0]);
        close(pipefd2[1]);
        free(buf);
        exit(0);
    } else {
        /* 父进程 */
        close(pipefd1[0]);
        close(pipefd2[1]);

        start = now();
        for (i = 0; i < iterations; i++) {
            write(pipefd1[1], buf, datasize);
            read(pipefd2[0], buf, datasize);
        }
        end = now();

        close(pipefd1[1]);
        close(pipefd2[0]);

        wait(NULL);
        free(buf);

        /* 返回单次切换延迟（微秒） */
        /* 每次迭代有2次上下文切换 */
        return (end - start) / (iterations * 2) * 1000000.0;
    }

    return 0;
}

/* 测试pipe通信延迟 */
double test_pipe_latency(int iterations, int datasize)
{
    int pipefd[2];
    char *buf;
    double start, end;
    int i;
    pid_t pid;

    buf = malloc(datasize);
    if (!buf) {
        perror("malloc");
        return -1.0;
    }
    memset(buf, 'x', datasize);

    if (pipe(pipefd) < 0) {
        perror("pipe");
        free(buf);
        return -1.0;
    }

    pid = fork();
    if (pid < 0) {
        perror("fork");
        free(buf);
        return -1.0;
    }

    if (pid == 0) {
        /* 子进程 - 只读 */
        close(pipefd[1]);
        for (i = 0; i < iterations; i++) {
            read(pipefd[0], buf, datasize);
        }
        close(pipefd[0]);
        free(buf);
        exit(0);
    } else {
        /* 父进程 - 只写 */
        close(pipefd[0]);
        start = now();
        for (i = 0; i < iterations; i++) {
            write(pipefd[1], buf, datasize);
        }
        end = now();
        close(pipefd[1]);
        wait(NULL);
        free(buf);

        return (end - start) / iterations * 1000000.0;
    }

    return 0;
}

int main(int argc, char *argv[])
{
    int iterations = ITERATIONS;
    int sizes[] = {0, 16, 64, 256, 1024, 4096};
    int i;
    double latency;

    if (argc > 1) {
        iterations = atoi(argv[1]);
        if (iterations <= 0) {
            iterations = ITERATIONS;
        }
    }

    printf("============================================\n");
    printf("Context Switch Latency Benchmark\n");
    printf("============================================\n");
    printf("Iterations: %d\n", iterations);
    printf("\n");

    printf("%-30s %15s\n", "Test", "Latency (us)");
    printf("--------------------------------------------\n");

    /* 测试不同数据大小的上下文切换 */
    for (i = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++) {
        char desc[100];
        snprintf(desc, sizeof(desc), "Process ctx switch (%d bytes)", sizes[i]);

        latency = test_process_ctx(iterations, sizes[i]);
        if (latency >= 0) {
            printf("%-30s %15.3f\n", desc, latency);
        }
    }

    printf("\n");
    printf("%-30s %15s\n", "IPC Mechanism", "Latency (us)");
    printf("--------------------------------------------\n");

    /* 测试pipe通信延迟 */
    for (i = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++) {
        char desc[100];
        snprintf(desc, sizeof(desc), "Pipe (%d bytes)", sizes[i]);

        latency = test_pipe_latency(iterations, sizes[i]);
        if (latency >= 0) {
            printf("%-30s %15.3f\n", desc, latency);
        }
    }

    printf("============================================\n");

    return 0;
}
