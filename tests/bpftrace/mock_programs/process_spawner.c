/*
 * process_spawner.c - 进程创建模拟程序
 * 用于测试 bpftrace 进程生命周期跟踪
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[]) {
    int count = 10;
    int interval = 1;
    int i;
    pid_t pid;

    if (argc > 1) {
        count = atoi(argv[1]);
    }
    if (argc > 2) {
        interval = atoi(argv[2]);
    }

    printf("Process Spawner - 进程创建模拟程序\n");
    printf("将创建 %d 个子进程\n", count);
    printf("间隔: %d 秒\n", interval);
    printf("父进程 PID: %d\n", getpid());
    printf("\n");

    printf("使用 bpftrace 跟踪进程创建:\n");
    printf("  sudo bpftrace -e 'tracepoint:sched:sched_process_exec ");
    printf("{ printf(\"%%s[%%d] exec: %%s\\n\", comm, pid, str(args->filename)); }'\n");
    printf("  sudo bpftrace -e 'tracepoint:sched:sched_process_fork ");
    printf("{ printf(\"%%s[%%d] fork -> %%d\\n\", comm, pid, args->child_pid); }'\n\n");

    sleep(3);  // 给时间启动 bpftrace

    printf("开始创建进程...\n\n");

    for (i = 0; i < count; i++) {
        pid = fork();

        if (pid < 0) {
            perror("fork");
            continue;
        } else if (pid == 0) {
            // 子进程
            printf("  [子进程 %d] PID: %d\n", i + 1, getpid());

            // 执行不同的命令
            if (i % 3 == 0) {
                execlp("/bin/echo", "echo", "Hello from child", NULL);
            } else if (i % 3 == 1) {
                execlp("/bin/date", "date", NULL);
            } else {
                execlp("/usr/bin/whoami", "whoami", NULL);
            }

            // 如果 exec 失败
            exit(1);
        } else {
            // 父进程
            printf("[父进程] 创建子进程 %d (PID: %d)\n", i + 1, pid);

            // 等待子进程
            waitpid(pid, NULL, 0);

            if (i < count - 1) {
                sleep(interval);
            }
        }
    }

    printf("\n完成！共创建 %d 个子进程\n", count);

    return 0;
}
