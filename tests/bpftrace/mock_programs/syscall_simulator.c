/*
 * syscall_simulator.c - 系统调用模拟程序
 * 用于测试 bpftrace 系统调用统计
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>

int main(int argc, char *argv[]) {
    int iterations = 100;
    int i;
    int fd;
    char buffer[256];
    struct stat st;
    struct timeval tv;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    }

    printf("Syscall Simulator - 系统调用模拟程序\n");
    printf("将执行 %d 次各种系统调用\n", iterations);
    printf("PID: %d\n", getpid());
    printf("\n");

    printf("使用 bpftrace 跟踪:\n");
    printf("  sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter /pid == %d/ { @[comm] = count(); }'\n", getpid());
    printf("  sudo bpftrace -e 'tracepoint:syscalls:sys_enter_* /pid == %d/ { @[probe] = count(); }'\n\n", getpid());

    sleep(2);  // 给时间启动 bpftrace

    printf("开始执行系统调用...\n");

    for (i = 0; i < iterations; i++) {
        // getpid - 简单系统调用
        getpid();

        // gettimeofday - 时间相关
        gettimeofday(&tv, NULL);

        // open - 文件操作
        fd = open("/etc/hosts", O_RDONLY);
        if (fd >= 0) {
            // read
            read(fd, buffer, sizeof(buffer));
            // close
            close(fd);
        }

        // stat - 文件状态
        stat("/etc/passwd", &st);

        // nanosleep - 休眠
        struct timespec ts = {0, 1000000};  // 1ms
        nanosleep(&ts, NULL);

        if ((i + 1) % 10 == 0) {
            printf("  进度: %d/%d\n", i + 1, iterations);
        }
    }

    printf("\n完成！共执行了约 %d 次系统调用\n", iterations * 6);
    printf("类型包括: getpid, gettimeofday, open, read, close, stat, nanosleep\n");

    return 0;
}
