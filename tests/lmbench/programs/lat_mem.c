/*
 * lat_mem.c - 内存访问延迟测试
 * 测量不同步长的内存访问延迟，用于检测缓存层次
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <stdint.h>

#define MAX_SIZE (64 * 1024 * 1024)  /* 64MB */
#define ITERATIONS 10000000

static inline double now(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec + (double)tv.tv_usec / 1000000.0;
}

/* 随机访问测试 */
double test_random_access(size_t size, size_t stride, int iterations)
{
    char *mem;
    size_t i, next;
    double start, end;
    volatile char tmp;
    size_t count;

    /* 分配并初始化内存 */
    mem = malloc(size);
    if (!mem) {
        perror("malloc");
        return -1.0;
    }
    memset(mem, 0, size);

    /* 创建指针链 */
    count = size / stride;
    for (i = 0; i < count; i++) {
        next = (i + 1) % count;
        *(size_t *)(mem + i * stride) = next * stride;
    }

    /* 预热 */
    next = 0;
    for (i = 0; i < 1000; i++) {
        next = *(size_t *)(mem + next);
    }

    /* 测试 */
    start = now();
    next = 0;
    for (i = 0; i < iterations; i++) {
        next = *(size_t *)(mem + next);
    }
    end = now();
    tmp = mem[next]; /* 防止优化 */

    free(mem);

    return (end - start) / iterations * 1000000000.0; /* 返回纳秒 */
}

/* 顺序访问测试 */
double test_sequential_access(size_t size, int iterations)
{
    char *mem;
    size_t i;
    double start, end;
    volatile char tmp;

    mem = malloc(size);
    if (!mem) {
        perror("malloc");
        return -1.0;
    }
    memset(mem, 0, size);

    /* 预热 */
    for (i = 0; i < size; i += 64) {
        tmp = mem[i];
    }

    /* 测试 */
    start = now();
    for (int iter = 0; iter < iterations; iter++) {
        for (i = 0; i < size; i += 64) {
            tmp = mem[i];
        }
    }
    end = now();

    free(mem);

    return (end - start) / (iterations * (size / 64)) * 1000000000.0;
}

int main(int argc, char *argv[])
{
    /* 测试大小：从4KB到64MB */
    size_t sizes[] = {
        4*1024,      /* 4KB - L1 */
        32*1024,     /* 32KB - L1 */
        256*1024,    /* 256KB - L2 */
        1*1024*1024, /* 1MB - L2/L3 */
        8*1024*1024, /* 8MB - L3 */
        32*1024*1024,/* 32MB - RAM */
        64*1024*1024 /* 64MB - RAM */
    };

    /* 测试步长 */
    size_t strides[] = {64, 128, 256, 512, 1024, 4096};

    int i, j;
    double latency;
    int iterations;

    printf("============================================\n");
    printf("Memory Latency Benchmark\n");
    printf("============================================\n");
    printf("\n");

    printf("Random Access Latency (stride = 64 bytes)\n");
    printf("%-15s %15s %15s\n", "Size", "Latency (ns)", "Level");
    printf("--------------------------------------------\n");

    for (i = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++) {
        /* 根据大小调整迭代次数 */
        if (sizes[i] <= 256*1024) {
            iterations = ITERATIONS;
        } else if (sizes[i] <= 8*1024*1024) {
            iterations = ITERATIONS / 10;
        } else {
            iterations = ITERATIONS / 100;
        }

        latency = test_random_access(sizes[i], 64, iterations);

        /* 判断缓存层次 */
        const char *level;
        if (sizes[i] <= 64*1024) {
            level = "L1";
        } else if (sizes[i] <= 512*1024) {
            level = "L2";
        } else if (sizes[i] <= 16*1024*1024) {
            level = "L3";
        } else {
            level = "RAM";
        }

        if (latency >= 0) {
            printf("%-15zu %15.2f %15s\n", sizes[i], latency, level);
        }
    }

    printf("\n");
    printf("Latency vs. Stride (size = 8MB)\n");
    printf("%-15s %15s\n", "Stride (bytes)", "Latency (ns)");
    printf("--------------------------------------------\n");

    for (j = 0; j < sizeof(strides)/sizeof(strides[0]); j++) {
        latency = test_random_access(8*1024*1024, strides[j], ITERATIONS/10);
        if (latency >= 0) {
            printf("%-15zu %15.2f\n", strides[j], latency);
        }
    }

    printf("\n");
    printf("Sequential Access Latency\n");
    printf("%-15s %15s\n", "Size", "Latency (ns)");
    printf("--------------------------------------------\n");

    for (i = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++) {
        if (sizes[i] <= 8*1024*1024) {
            iterations = 1000;
        } else {
            iterations = 100;
        }

        latency = test_sequential_access(sizes[i], iterations);
        if (latency >= 0) {
            printf("%-15zu %15.2f\n", sizes[i], latency);
        }
    }

    printf("============================================\n");

    return 0;
}
