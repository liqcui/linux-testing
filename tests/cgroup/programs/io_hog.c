/*
 * io_hog.c - I/O密集型程序用于cgroup I/O测试
 *
 * 可配置读写大小和模式
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>
#include <sys/stat.h>

static volatile int running = 1;

static void sigint_handler(int sig)
{
    (void)sig;
    running = 0;
}

static void io_test(const char *path, size_t file_size_mb, int mode)
{
    char filename[512];
    int fd;
    char *buffer;
    size_t buffer_size = 1024 * 1024;  // 1MB buffer
    size_t total_bytes = file_size_mb * 1024 * 1024;
    size_t written = 0, read_bytes = 0;
    struct timeval start, end;
    double elapsed;

    snprintf(filename, sizeof(filename), "%s/io_test_%d.dat", path, getpid());

    buffer = malloc(buffer_size);
    if (!buffer) {
        fprintf(stderr, "无法分配缓冲区\n");
        return;
    }

    // 填充测试数据
    for (size_t i = 0; i < buffer_size; i++) {
        buffer[i] = (char)(i & 0xFF);
    }

    printf("测试文件: %s\n", filename);
    printf("文件大小: %zu MB\n", file_size_mb);
    printf("缓冲区大小: %zu bytes\n", buffer_size);
    printf("模式: %d (0=写入, 1=读取, 2=读写)\n", mode);
    printf("\n");

    // 写入测试
    if (mode == 0 || mode == 2) {
        printf("开始写入测试...\n");
        gettimeofday(&start, NULL);

        fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd < 0) {
            perror("打开文件失败");
            free(buffer);
            return;
        }

        while (written < total_bytes && running) {
            size_t to_write = (total_bytes - written > buffer_size) ? buffer_size : (total_bytes - written);
            ssize_t ret = write(fd, buffer, to_write);

            if (ret < 0) {
                perror("写入失败");
                break;
            }

            written += ret;

            if (written % (10 * 1024 * 1024) == 0) {
                printf("  已写入: %zu MB\n", written / 1024 / 1024);
            }
        }

        fsync(fd);
        close(fd);

        gettimeofday(&end, NULL);
        elapsed = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0;

        printf("\n写入完成:\n");
        printf("  总量: %zu MB\n", written / 1024 / 1024);
        printf("  耗时: %.2f 秒\n", elapsed);
        printf("  吞吐量: %.2f MB/s\n", (written / 1024.0 / 1024.0) / elapsed);
        printf("\n");
    }

    // 读取测试
    if (mode == 1 || mode == 2) {
        printf("开始读取测试...\n");

        // 如果只做读取测试，需要先创建文件
        if (mode == 1) {
            fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
            if (fd < 0) {
                perror("创建文件失败");
                free(buffer);
                return;
            }

            while (written < total_bytes) {
                size_t to_write = (total_bytes - written > buffer_size) ? buffer_size : (total_bytes - written);
                write(fd, buffer, to_write);
                written += to_write;
            }

            fsync(fd);
            close(fd);
            printf("  测试文件已创建\n");
        }

        gettimeofday(&start, NULL);

        fd = open(filename, O_RDONLY);
        if (fd < 0) {
            perror("打开文件失败");
            free(buffer);
            return;
        }

        while (running) {
            ssize_t ret = read(fd, buffer, buffer_size);

            if (ret <= 0) {
                break;
            }

            read_bytes += ret;

            if (read_bytes % (10 * 1024 * 1024) == 0) {
                printf("  已读取: %zu MB\n", read_bytes / 1024 / 1024);
            }
        }

        close(fd);

        gettimeofday(&end, NULL);
        elapsed = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) / 1000000.0;

        printf("\n读取完成:\n");
        printf("  总量: %zu MB\n", read_bytes / 1024 / 1024);
        printf("  耗时: %.2f 秒\n", elapsed);
        printf("  吞吐量: %.2f MB/s\n", (read_bytes / 1024.0 / 1024.0) / elapsed);
        printf("\n");
    }

    // 清理
    printf("删除测试文件...\n");
    unlink(filename);

    free(buffer);
    printf("✓ 测试完成\n");
}

int main(int argc, char *argv[])
{
    const char *path = "/tmp";
    size_t file_size_mb = 100;
    int mode = 2;  // 默认读写模式

    if (argc > 1) {
        file_size_mb = atoi(argv[1]);
    }
    if (argc > 2) {
        mode = atoi(argv[2]);
    }
    if (argc > 3) {
        path = argv[3];
    }

    if (file_size_mb < 1 || file_size_mb > 10000) {
        fprintf(stderr, "文件大小必须在1-10000 MB之间\n");
        return 1;
    }

    if (mode < 0 || mode > 2) {
        fprintf(stderr, "模式必须是0(写), 1(读), 或2(读写)\n");
        return 1;
    }

    printf("========================================\n");
    printf("I/O密集型测试程序\n");
    printf("========================================\n");
    printf("文件大小: %zu MB\n", file_size_mb);
    printf("测试路径: %s\n", path);
    printf("测试模式: %d\n", mode);
    printf("进程PID: %d\n", getpid());
    printf("========================================\n\n");

    signal(SIGINT, sigint_handler);
    signal(SIGTERM, sigint_handler);

    io_test(path, file_size_mb, mode);

    printf("\n========================================\n");
    printf("测试完成\n");
    printf("========================================\n");

    return 0;
}
