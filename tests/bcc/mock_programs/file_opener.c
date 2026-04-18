/*
 * file_opener.c - 文件打开模拟程序
 * 用于测试 opensnoop
 */

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    int i;
    int fd;
    int iterations = 10;
    int delay_ms = 500;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    }
    if (argc > 2) {
        delay_ms = atoi(argv[2]);
    }

    printf("File Opener - 模拟文件打开操作\n");
    printf("迭代次数: %d\n", iterations);
    printf("间隔: %d ms\n\n", delay_ms);

    for (i = 0; i < iterations; i++) {
        printf("[%d/%d] ", i + 1, iterations);

        // 1. 成功打开 /etc/hosts
        fd = open("/etc/hosts", O_RDONLY);
        if (fd >= 0) {
            printf("✓ 打开 /etc/hosts (fd=%d) ", fd);
            close(fd);
        }

        // 2. 成功打开 /etc/passwd
        fd = open("/etc/passwd", O_RDONLY);
        if (fd >= 0) {
            printf("✓ 打开 /etc/passwd (fd=%d) ", fd);
            close(fd);
        }

        // 3. 尝试打开不存在的文件（失败）
        fd = open("/tmp/nonexistent_file_12345.txt", O_RDONLY);
        if (fd < 0) {
            printf("✗ 打开失败 /tmp/nonexistent_file_12345.txt (errno=%d) ", errno);
        } else {
            close(fd);
        }

        printf("\n");

        usleep(delay_ms * 1000);
    }

    printf("\n完成！共执行 %d 次文件打开操作\n", iterations * 3);
    return 0;
}
