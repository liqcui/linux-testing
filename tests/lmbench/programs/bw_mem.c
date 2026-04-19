/*
 * bw_mem.c - 内存带宽测试
 * 测量不同操作的内存带宽（读、写、拷贝）
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define DEFAULT_SIZE (64 * 1024 * 1024)  /* 64MB */
#define ITERATIONS 10

static inline double now(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec + (double)tv.tv_usec / 1000000.0;
}

/* 读带宽测试 */
double test_read_bandwidth(size_t size, int iterations)
{
    char *mem;
    size_t i;
    double start, end;
    volatile long long sum = 0;
    int iter;

    mem = malloc(size);
    if (!mem) {
        perror("malloc");
        return -1.0;
    }
    memset(mem, 0xAA, size);

    /* 预热 */
    for (i = 0; i < size; i += sizeof(long long)) {
        sum += *(long long *)(mem + i);
    }

    /* 测试 */
    start = now();
    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < size; i += sizeof(long long)) {
            sum += *(long long *)(mem + i);
        }
    }
    end = now();

    free(mem);

    /* 返回 MB/s */
    return (size * iterations) / (end - start) / 1024.0 / 1024.0;
}

/* 写带宽测试 */
double test_write_bandwidth(size_t size, int iterations)
{
    char *mem;
    size_t i;
    double start, end;
    int iter;

    mem = malloc(size);
    if (!mem) {
        perror("malloc");
        return -1.0;
    }

    /* 预热 */
    memset(mem, 0, size);

    /* 测试 */
    start = now();
    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < size; i += sizeof(long long)) {
            *(long long *)(mem + i) = 0xDEADBEEFDEADBEEF;
        }
    }
    end = now();

    free(mem);

    return (size * iterations) / (end - start) / 1024.0 / 1024.0;
}

/* 拷贝带宽测试 */
double test_copy_bandwidth(size_t size, int iterations)
{
    char *src, *dst;
    double start, end;
    int iter;

    src = malloc(size);
    dst = malloc(size);
    if (!src || !dst) {
        perror("malloc");
        if (src) free(src);
        if (dst) free(dst);
        return -1.0;
    }

    memset(src, 0xAA, size);
    memset(dst, 0, size);

    /* 预热 */
    memcpy(dst, src, size);

    /* 测试 */
    start = now();
    for (iter = 0; iter < iterations; iter++) {
        memcpy(dst, src, size);
    }
    end = now();

    free(src);
    free(dst);

    return (size * iterations) / (end - start) / 1024.0 / 1024.0;
}

/* 读修改写带宽测试 */
double test_rdwr_bandwidth(size_t size, int iterations)
{
    char *mem;
    size_t i;
    double start, end;
    int iter;

    mem = malloc(size);
    if (!mem) {
        perror("malloc");
        return -1.0;
    }
    memset(mem, 0, size);

    /* 预热 */
    for (i = 0; i < size; i += sizeof(long long)) {
        *(long long *)(mem + i) = *(long long *)(mem + i) + 1;
    }

    /* 测试 */
    start = now();
    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < size; i += sizeof(long long)) {
            *(long long *)(mem + i) = *(long long *)(mem + i) + 1;
        }
    }
    end = now();

    free(mem);

    return (size * iterations) / (end - start) / 1024.0 / 1024.0;
}

int main(int argc, char *argv[])
{
    size_t size = DEFAULT_SIZE;
    int iterations = ITERATIONS;
    double bandwidth;

    if (argc > 1) {
        size = atoll(argv[1]) * 1024 * 1024; /* MB */
        if (size <= 0) {
            size = DEFAULT_SIZE;
        }
    }

    if (argc > 2) {
        iterations = atoi(argv[2]);
        if (iterations <= 0) {
            iterations = ITERATIONS;
        }
    }

    printf("============================================\n");
    printf("Memory Bandwidth Benchmark\n");
    printf("============================================\n");
    printf("Buffer size: %.1f MB\n", size / 1024.0 / 1024.0);
    printf("Iterations: %d\n", iterations);
    printf("\n");

    printf("%-25s %15s\n", "Operation", "Bandwidth (MB/s)");
    printf("--------------------------------------------\n");

    bandwidth = test_read_bandwidth(size, iterations);
    if (bandwidth >= 0) {
        printf("%-25s %15.2f\n", "Read", bandwidth);
    }

    bandwidth = test_write_bandwidth(size, iterations);
    if (bandwidth >= 0) {
        printf("%-25s %15.2f\n", "Write", bandwidth);
    }

    bandwidth = test_copy_bandwidth(size, iterations);
    if (bandwidth >= 0) {
        printf("%-25s %15.2f\n", "Copy (memcpy)", bandwidth);
    }

    bandwidth = test_rdwr_bandwidth(size, iterations);
    if (bandwidth >= 0) {
        printf("%-25s %15.2f\n", "Read-Modify-Write", bandwidth);
    }

    printf("============================================\n");

    return 0;
}
