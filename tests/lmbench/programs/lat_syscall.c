/*
 * lat_syscall.c - 系统调用延迟测试
 * 测量各种系统调用的延迟时间
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/time.h>
#include <string.h>

#define ITERATIONS 100000

/* 高精度计时 */
static inline double now(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec + (double)tv.tv_usec / 1000000.0;
}

/* 测试getpid系统调用 */
double test_getpid(int iterations)
{
    double start, end;
    int i;
    volatile pid_t pid;

    start = now();
    for (i = 0; i < iterations; i++) {
        pid = getpid();
    }
    end = now();

    return (end - start) / iterations * 1000000.0; /* 返回微秒 */
}

/* 测试getppid系统调用 */
double test_getppid(int iterations)
{
    double start, end;
    int i;
    volatile pid_t pid;

    start = now();
    for (i = 0; i < iterations; i++) {
        pid = getppid();
    }
    end = now();

    return (end - start) / iterations * 1000000.0;
}

/* 测试getuid系统调用 */
double test_getuid(int iterations)
{
    double start, end;
    int i;
    volatile uid_t uid;

    start = now();
    for (i = 0; i < iterations; i++) {
        uid = getuid();
    }
    end = now();

    return (end - start) / iterations * 1000000.0;
}

/* 测试open/close系统调用 */
double test_open_close(int iterations)
{
    double start, end;
    int i, fd;
    char tmpfile[] = "/tmp/lat_syscall_XXXXXX";

    /* 创建临时文件 */
    fd = mkstemp(tmpfile);
    if (fd < 0) {
        perror("mkstemp");
        return -1.0;
    }
    close(fd);

    start = now();
    for (i = 0; i < iterations; i++) {
        fd = open(tmpfile, O_RDONLY);
        if (fd >= 0) {
            close(fd);
        }
    }
    end = now();

    unlink(tmpfile);

    return (end - start) / iterations * 1000000.0;
}

/* 测试stat系统调用 */
double test_stat(int iterations)
{
    double start, end;
    int i;
    struct stat st;
    char tmpfile[] = "/tmp/lat_syscall_XXXXXX";
    int fd;

    /* 创建临时文件 */
    fd = mkstemp(tmpfile);
    if (fd < 0) {
        perror("mkstemp");
        return -1.0;
    }
    close(fd);

    start = now();
    for (i = 0; i < iterations; i++) {
        stat(tmpfile, &st);
    }
    end = now();

    unlink(tmpfile);

    return (end - start) / iterations * 1000000.0;
}

/* 测试read系统调用（空读） */
double test_read(int iterations)
{
    double start, end;
    int i, fd;
    char buf[1];
    int pipefd[2];

    if (pipe(pipefd) < 0) {
        perror("pipe");
        return -1.0;
    }

    /* 使管道可读 */
    write(pipefd[1], "x", 1);

    start = now();
    for (i = 0; i < iterations; i++) {
        read(pipefd[0], buf, 0); /* 读0字节 */
    }
    end = now();

    close(pipefd[0]);
    close(pipefd[1]);

    return (end - start) / iterations * 1000000.0;
}

/* 测试write系统调用（写到/dev/null） */
double test_write(int iterations)
{
    double start, end;
    int i, fd;
    char buf[1] = {'x'};

    fd = open("/dev/null", O_WRONLY);
    if (fd < 0) {
        perror("open /dev/null");
        return -1.0;
    }

    start = now();
    for (i = 0; i < iterations; i++) {
        write(fd, buf, 1);
    }
    end = now();

    close(fd);

    return (end - start) / iterations * 1000000.0;
}

int main(int argc, char *argv[])
{
    int iterations = ITERATIONS;
    double latency;

    if (argc > 1) {
        iterations = atoi(argv[1]);
        if (iterations <= 0) {
            iterations = ITERATIONS;
        }
    }

    printf("============================================\n");
    printf("System Call Latency Benchmark\n");
    printf("============================================\n");
    printf("Iterations: %d\n", iterations);
    printf("\n");

    printf("%-20s %15s\n", "System Call", "Latency (us)");
    printf("--------------------------------------------\n");

    latency = test_getpid(iterations);
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "getpid()", latency);
    }

    latency = test_getppid(iterations);
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "getppid()", latency);
    }

    latency = test_getuid(iterations);
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "getuid()", latency);
    }

    latency = test_open_close(iterations / 10); /* open/close慢，减少迭代 */
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "open/close", latency);
    }

    latency = test_stat(iterations / 10);
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "stat()", latency);
    }

    latency = test_read(iterations);
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "read(0 bytes)", latency);
    }

    latency = test_write(iterations);
    if (latency >= 0) {
        printf("%-20s %15.3f\n", "write(1 byte)", latency);
    }

    printf("============================================\n");

    return 0;
}
