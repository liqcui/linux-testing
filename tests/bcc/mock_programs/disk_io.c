/*
 * disk_io.c - 磁盘 I/O 模拟程序
 * 用于测试 biosnoop
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#define BUFFER_SIZE 4096

int main(int argc, char *argv[]) {
    int i;
    int fd;
    char buffer[BUFFER_SIZE];
    int iterations = 10;
    int delay_ms = 1000;
    const char *test_file = "/tmp/biosnoop_test.dat";
    ssize_t bytes;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    }
    if (argc > 2) {
        delay_ms = atoi(argv[2]);
    }

    printf("Disk I/O Simulator - 磁盘 I/O 模拟程序\n");
    printf("测试文件: %s\n", test_file);
    printf("迭代次数: %d\n", iterations);
    printf("间隔: %d ms\n\n", delay_ms);

    // 初始化缓冲区
    memset(buffer, 'A', BUFFER_SIZE);

    for (i = 0; i < iterations; i++) {
        printf("[%d/%d] ", i + 1, iterations);

        // 1. 写操作
        fd = open(test_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            perror("open for write");
            continue;
        }

        bytes = write(fd, buffer, BUFFER_SIZE);
        if (bytes > 0) {
            printf("✓ 写入 %zd bytes ", bytes);
        }
        fsync(fd);  // 强制刷新到磁盘
        close(fd);

        usleep(100000);  // 100ms

        // 2. 读操作
        fd = open(test_file, O_RDONLY);
        if (fd < 0) {
            perror("open for read");
            continue;
        }

        bytes = read(fd, buffer, BUFFER_SIZE);
        if (bytes > 0) {
            printf("✓ 读取 %zd bytes ", bytes);
        }
        close(fd);

        usleep(100000);  // 100ms

        // 3. Direct I/O（绕过缓存）
        fd = open(test_file, O_RDONLY | O_DIRECT);
        if (fd >= 0) {
            // 对齐的缓冲区
            void *aligned_buf;
            if (posix_memalign(&aligned_buf, 512, BUFFER_SIZE) == 0) {
                bytes = read(fd, aligned_buf, BUFFER_SIZE);
                if (bytes > 0) {
                    printf("✓ Direct I/O 读取 %zd bytes", bytes);
                }
                free(aligned_buf);
            }
            close(fd);
        }

        printf("\n");
        usleep(delay_ms * 1000);
    }

    // 清理
    unlink(test_file);

    printf("\n完成！共执行 %d 次 I/O 操作\n", iterations * 3);
    return 0;
}
