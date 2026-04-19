/*
 * mem_hog.c - 内存密集型程序用于cgroup内存测试
 *
 * 可配置分配大小和访问模式
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>

static volatile int running = 1;

static void sigint_handler(int sig)
{
    (void)sig;
    running = 0;
}

static void allocate_and_use(size_t total_mb, int pattern)
{
    size_t chunk_size = 1024 * 1024;  // 1MB chunks
    size_t total_bytes = total_mb * 1024 * 1024;
    size_t num_chunks = total_bytes / chunk_size;
    char **chunks;
    size_t allocated = 0;
    struct timeval start, end;
    double elapsed;

    printf("开始分配内存: %zu MB\n", total_mb);
    printf("分配块大小: %zu bytes\n", chunk_size);
    printf("总块数: %zu\n", num_chunks);
    printf("访问模式: %d (0=写入, 1=读取, 2=读写)\n", pattern);
    printf("\n");

    chunks = malloc(num_chunks * sizeof(char *));
    if (!chunks) {
        fprintf(stderr, "无法分配块指针数组\n");
        return;
    }

    gettimeofday(&start, NULL);

    // 分配内存
    for (size_t i = 0; i < num_chunks && running; i++) {
        chunks[i] = malloc(chunk_size);
        if (!chunks[i]) {
            fprintf(stderr, "分配失败，已分配 %zu MB\n", allocated / 1024 / 1024);
            num_chunks = i;
            break;
        }

        // 写入数据以确保实际分配物理内存
        memset(chunks[i], (int)i & 0xFF, chunk_size);
        allocated += chunk_size;

        if ((i + 1) % 100 == 0) {
            printf("已分配: %zu MB\n", allocated / 1024 / 1024);
        }
    }

    gettimeofday(&end, NULL);
    elapsed = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0;

    printf("\n分配完成:\n");
    printf("  总量: %zu MB\n", allocated / 1024 / 1024);
    printf("  耗时: %.2f 秒\n", elapsed);
    printf("  速率: %.2f MB/s\n", (allocated / 1024.0 / 1024.0) / elapsed);
    printf("\n");

    // 访问内存
    printf("开始访问内存...\n");
    gettimeofday(&start, NULL);

    int iterations = 0;
    while (running) {
        for (size_t i = 0; i < num_chunks && running; i++) {
            switch (pattern) {
            case 0:  // 写入模式
                memset(chunks[i], (int)(i + iterations) & 0xFF, chunk_size);
                break;
            case 1:  // 读取模式
                {
                    volatile char sum = 0;
                    for (size_t j = 0; j < chunk_size; j += 4096) {
                        sum += chunks[i][j];
                    }
                }
                break;
            case 2:  // 读写模式
                for (size_t j = 0; j < chunk_size; j += 4096) {
                    chunks[i][j] = (chunks[i][j] + 1) & 0xFF;
                }
                break;
            }
        }

        iterations++;
        printf("访问迭代: %d\n", iterations);
        sleep(1);
    }

    gettimeofday(&end, NULL);
    elapsed = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0;

    printf("\n访问完成:\n");
    printf("  迭代次数: %d\n", iterations);
    printf("  总耗时: %.2f 秒\n", elapsed);
    printf("\n");

    // 释放内存
    printf("释放内存...\n");
    for (size_t i = 0; i < num_chunks; i++) {
        free(chunks[i]);
    }
    free(chunks);

    printf("✓ 内存已释放\n");
}

int main(int argc, char *argv[])
{
    size_t memory_mb = 100;  // 默认100MB
    int pattern = 2;  // 默认读写模式

    if (argc > 1) {
        memory_mb = atoi(argv[1]);
    }
    if (argc > 2) {
        pattern = atoi(argv[2]);
    }

    if (memory_mb < 1 || memory_mb > 100000) {
        fprintf(stderr, "内存大小必须在1-100000 MB之间\n");
        return 1;
    }

    if (pattern < 0 || pattern > 2) {
        fprintf(stderr, "访问模式必须是0(写), 1(读), 或2(读写)\n");
        return 1;
    }

    printf("========================================\n");
    printf("内存密集型测试程序\n");
    printf("========================================\n");
    printf("目标内存: %zu MB\n", memory_mb);
    printf("访问模式: %d\n", pattern);
    printf("进程PID: %d\n", getpid());
    printf("========================================\n\n");

    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    allocate_and_use(memory_mb, pattern);

    printf("\n========================================\n");
    printf("测试完成\n");
    printf("========================================\n");

    return 0;
}
