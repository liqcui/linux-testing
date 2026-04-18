/*
 * io_generator.c - I/O 操作生成器
 * 用于测试 bpftrace 文件系统操作跟踪
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

int main(int argc, char *argv[]) {
    const char *operation = "write";
    int count = 100;
    size_t size = 4096;
    int i, fd;
    char *buffer;
    const char *test_file = "/tmp/bpftrace_io_test.dat";
    ssize_t bytes;

    if (argc > 1) {
        operation = argv[1];
    }
    if (argc > 2) {
        count = atoi(argv[2]);
    }
    if (argc > 3) {
        size = atoll(argv[3]);
    }

    printf("I/O Generator - I/O 操作生成器\n");
    printf("操作类型: %s\n", operation);
    printf("操作次数: %d\n", count);
    printf("每次大小: %zu bytes\n", size);
    printf("PID: %d\n", getpid());
    printf("\n");

    printf("使用 bpftrace 跟踪:\n");
    printf("  # 跟踪 VFS 读写\n");
    printf("  sudo bpftrace -e 'kprobe:vfs_read,kprobe:vfs_write /pid == %d/ { @[probe] = count(); }'\n", getpid());
    printf("  # 跟踪读写字节数\n");
    printf("  sudo bpftrace -e 'tracepoint:syscalls:sys_enter_read,tracepoint:syscalls:sys_enter_write /pid == %d/ ");
    printf("{ @bytes[probe] = sum(args->count); }'\n\n", getpid());

    sleep(2);  // 给时间启动 bpftrace

    buffer = malloc(size);
    if (!buffer) {
        perror("malloc");
        return 1;
    }

    memset(buffer, 'A', size);

    if (strcmp(operation, "write") == 0) {
        printf("开始写操作...\n");

        fd = open(test_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            perror("open");
            free(buffer);
            return 1;
        }

        for (i = 0; i < count; i++) {
            bytes = write(fd, buffer, size);
            if (bytes > 0) {
                printf("  [%d/%d] 写入 %zd bytes\n", i + 1, count, bytes);
            }
            usleep(10000);  // 10ms
        }

        fsync(fd);
        close(fd);

        printf("\n完成！总共写入 %zu bytes (%.2f MB)\n",
               count * size, (count * size) / 1048576.0);

    } else if (strcmp(operation, "read") == 0) {
        printf("开始读操作...\n");

        // 先创建文件
        fd = open(test_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            perror("open for write");
            free(buffer);
            return 1;
        }

        for (i = 0; i < count; i++) {
            write(fd, buffer, size);
        }
        close(fd);

        // 读取
        fd = open(test_file, O_RDONLY);
        if (fd < 0) {
            perror("open for read");
            free(buffer);
            return 1;
        }

        for (i = 0; i < count; i++) {
            bytes = read(fd, buffer, size);
            if (bytes > 0) {
                printf("  [%d/%d] 读取 %zd bytes\n", i + 1, count, bytes);
            }
            usleep(10000);  // 10ms
        }

        close(fd);

        printf("\n完成！总共读取 %zu bytes (%.2f MB)\n",
               count * size, (count * size) / 1048576.0);
    }

    // 清理
    unlink(test_file);
    free(buffer);

    return 0;
}
