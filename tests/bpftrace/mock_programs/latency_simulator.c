/*
 * latency_simulator.c - 延迟模拟程序
 * 用于测试 bpftrace 内核函数延迟跟踪
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>

int main(int argc, char *argv[]) {
    int iterations = 50;
    int i;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    }

    printf("Latency Simulator - 延迟模拟程序\n");
    printf("将产生各种延迟模式\n");
    printf("PID: %d\n", getpid());
    printf("\n");

    printf("使用 bpftrace 跟踪延迟:\n");
    printf("  sudo bpftrace -e 'kprobe:do_nanosleep { @start[tid] = nsecs; } ");
    printf("kretprobe:do_nanosleep /@start[tid]/ ");
    printf("{ @usecs = hist((nsecs - @start[tid]) / 1000); delete(@start[tid]); }'\n\n");

    sleep(2);  // 给时间启动 bpftrace

    printf("开始执行各种延迟操作...\n\n");

    for (i = 0; i < iterations; i++) {
        struct timespec ts;
        int sleep_us;

        // 产生不同的延迟
        if (i % 5 == 0) {
            sleep_us = 1000;      // 1ms
        } else if (i % 5 == 1) {
            sleep_us = 5000;      // 5ms
        } else if (i % 5 == 2) {
            sleep_us = 10000;     // 10ms
        } else if (i % 5 == 3) {
            sleep_us = 50000;     // 50ms
        } else {
            sleep_us = 100000;    // 100ms
        }

        ts.tv_sec = sleep_us / 1000000;
        ts.tv_nsec = (sleep_us % 1000000) * 1000;

        printf("[%d/%d] Sleep %d us\n", i + 1, iterations, sleep_us);
        nanosleep(&ts, NULL);
    }

    printf("\n完成！产生了多种延迟模式\n");
    printf("延迟范围: 1ms - 100ms\n");

    return 0;
}
