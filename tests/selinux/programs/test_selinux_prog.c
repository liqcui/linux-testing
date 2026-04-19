/*
 * test_selinux_prog.c - SELinux测试程序
 *
 * 用于测试SELinux策略是否正确工作
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <selinux/selinux.h>

static void print_context(const char *label)
{
    char *context = NULL;

    if (getcon(&context) == 0) {
        printf("%s SELinux上下文: %s\n", label, context);
        freecon(context);
    } else {
        printf("%s 无法获取SELinux上下文: %s\n", label, strerror(errno));
    }
}

static int test_file_access(const char *path, const char *mode)
{
    FILE *fp;
    char buffer[256];

    printf("\n测试文件访问: %s (模式: %s)\n", path, mode);

    fp = fopen(path, mode);
    if (fp == NULL) {
        printf("  ✗ 打开失败: %s\n", strerror(errno));
        return -1;
    }

    printf("  ✓ 打开成功\n");

    if (strchr(mode, 'r')) {
        if (fgets(buffer, sizeof(buffer), fp) != NULL) {
            printf("  ✓ 读取成功: %s", buffer);
        } else {
            printf("  ✗ 读取失败: %s\n", strerror(errno));
        }
    }

    if (strchr(mode, 'w')) {
        if (fprintf(fp, "测试数据: %ld\n", time(NULL)) > 0) {
            printf("  ✓ 写入成功\n");
        } else {
            printf("  ✗ 写入失败: %s\n", strerror(errno));
        }
    }

    fclose(fp);
    return 0;
}

static void test_process_operations(void)
{
    pid_t pid;

    printf("\n测试进程操作:\n");

    pid = fork();
    if (pid < 0) {
        printf("  ✗ fork失败: %s\n", strerror(errno));
        return;
    }

    if (pid == 0) {
        // 子进程
        printf("  ✓ fork成功 (子进程PID: %d)\n", getpid());
        print_context("  子进程");
        exit(0);
    } else {
        // 父进程
        printf("  ✓ fork成功 (父进程PID: %d, 子进程PID: %d)\n", getpid(), pid);
        wait(NULL);
    }
}

static void test_file_contexts(void)
{
    char *context = NULL;
    const char *files[] = {
        "/etc/passwd",
        "/tmp",
        "/var/log",
        NULL
    };
    int i;

    printf("\n测试文件上下文查询:\n");

    for (i = 0; files[i] != NULL; i++) {
        if (getfilecon(files[i], &context) >= 0) {
            printf("  %s: %s\n", files[i], context);
            freecon(context);
        } else {
            printf("  %s: 无法获取上下文 (%s)\n", files[i], strerror(errno));
        }
    }
}

int main(int argc, char *argv[])
{
    printf("========================================\n");
    printf("SELinux测试程序\n");
    printf("========================================\n\n");

    // 检查SELinux是否启用
    if (!is_selinux_enabled()) {
        printf("✗ SELinux未启用\n");
        return 1;
    }

    printf("✓ SELinux已启用\n");
    printf("  模式: %s\n", selinux_getenforcemode(NULL) == 0 ? "Permissive" : "Enforcing");
    printf("\n");

    // 打印当前上下文
    print_context("当前进程");

    // 测试文件上下文
    test_file_contexts();

    // 测试文件访问
    test_file_access("/etc/passwd", "r");
    test_file_access("/tmp/test_selinux_write", "w");
    test_file_access("/tmp/test_selinux_rw", "w+");

    // 测试进程操作
    test_process_operations();

    printf("\n========================================\n");
    printf("测试完成\n");
    printf("========================================\n");

    return 0;
}
