/*
 * namespace_test.c - Namespace测试程序
 *
 * 测试各种Linux namespace的创建和隔离效果
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sched.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

#define STACK_SIZE (1024 * 1024)

static char child_stack[STACK_SIZE];

// 子进程函数
static int child_func(void *arg)
{
    char *cmd = (char *)arg;

    printf("\n========================================\n");
    printf("子进程开始 (PID: %d)\n", getpid());
    printf("========================================\n\n");

    // 显示namespace信息
    printf("Namespace信息:\n");
    system("ls -l /proc/self/ns/");
    printf("\n");

    // 显示主机名
    char hostname[256];
    gethostname(hostname, sizeof(hostname));
    printf("主机名: %s\n", hostname);

    // 显示进程信息
    printf("\n进程信息:\n");
    printf("  PID: %d\n", getpid());
    printf("  PPID: %d\n", getppid());
    printf("  UID: %d\n", getuid());
    printf("  GID: %d\n", getgid());

    // 显示挂载点
    printf("\n挂载点 (部分):\n");
    system("mount | head -10");

    // 显示网络接口
    printf("\n网络接口:\n");
    system("ip link show 2>/dev/null || ifconfig -a");

    // 执行自定义命令
    if (cmd && strlen(cmd) > 0) {
        printf("\n执行命令: %s\n", cmd);
        printf("----------------------------------------\n");
        system(cmd);
    }

    printf("\n========================================\n");
    printf("子进程结束\n");
    printf("========================================\n");

    return 0;
}

static void print_usage(const char *prog)
{
    printf("用法: %s [选项]\n", prog);
    printf("选项:\n");
    printf("  -p    使用PID namespace\n");
    printf("  -n    使用Network namespace\n");
    printf("  -u    使用UTS namespace (hostname)\n");
    printf("  -i    使用IPC namespace\n");
    printf("  -m    使用Mount namespace\n");
    printf("  -U    使用User namespace\n");
    printf("  -c    在新namespace中执行的命令\n");
    printf("  -h    显示帮助\n");
    printf("\n");
    printf("示例:\n");
    printf("  %s -p -n              # PID + Network namespace\n", prog);
    printf("  %s -p -u -c 'ps aux'  # PID + UTS namespace，执行ps命令\n", prog);
    printf("  %s -U                 # User namespace\n", prog);
}

int main(int argc, char *argv[])
{
    int flags = 0;
    char *cmd = NULL;
    int opt;
    pid_t pid;
    int status;

    printf("========================================\n");
    printf("Namespace 测试程序\n");
    printf("========================================\n\n");

    // 解析命令行参数
    while ((opt = getopt(argc, argv, "pnuimUc:h")) != -1) {
        switch (opt) {
        case 'p':
            flags |= CLONE_NEWPID;
            printf("启用: PID namespace\n");
            break;
        case 'n':
            flags |= CLONE_NEWNET;
            printf("启用: Network namespace\n");
            break;
        case 'u':
            flags |= CLONE_NEWUTS;
            printf("启用: UTS namespace\n");
            break;
        case 'i':
            flags |= CLONE_NEWIPC;
            printf("启用: IPC namespace\n");
            break;
        case 'm':
            flags |= CLONE_NEWNS;
            printf("启用: Mount namespace\n");
            break;
        case 'U':
            flags |= CLONE_NEWUSER;
            printf("启用: User namespace\n");
            break;
        case 'c':
            cmd = optarg;
            printf("命令: %s\n", cmd);
            break;
        case 'h':
            print_usage(argv[0]);
            return 0;
        default:
            print_usage(argv[0]);
            return 1;
        }
    }

    if (flags == 0) {
        printf("错误: 必须指定至少一个namespace类型\n\n");
        print_usage(argv[0]);
        return 1;
    }

    printf("\n父进程信息:\n");
    printf("  PID: %d\n", getpid());
    printf("  UID: %d\n", getuid());
    printf("  GID: %d\n", getgid());

    printf("\n父进程 Namespace:\n");
    system("ls -l /proc/self/ns/");

    printf("\n创建新namespace...\n");

    // 使用clone创建子进程
    pid = clone(child_func, child_stack + STACK_SIZE,
                SIGCHLD | flags, cmd);

    if (pid == -1) {
        perror("clone失败");
        printf("\n可能原因:\n");
        printf("  1. 权限不足（需要root权限或CAP_SYS_ADMIN）\n");
        printf("  2. 内核不支持该namespace类型\n");
        printf("  3. 资源限制\n");
        return 1;
    }

    printf("✓ 子进程已创建 (PID: %d)\n", pid);
    printf("\n等待子进程完成...\n");

    // 等待子进程结束
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        return 1;
    }

    printf("\n子进程退出状态: %d\n", WEXITSTATUS(status));

    printf("\n========================================\n");
    printf("测试完成\n");
    printf("========================================\n");

    return 0;
}
