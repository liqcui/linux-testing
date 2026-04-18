/*
 * memory_leaker.c - 内存泄漏模拟程序
 * 用于测试 memleak
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LEAK_SIZE 1024

// 故意泄漏的内存指针
void *leaked_memory[100];
int leak_count = 0;

void leak_memory_small() {
    void *ptr = malloc(LEAK_SIZE);
    if (ptr) {
        memset(ptr, 'A', LEAK_SIZE);
        // 故意不释放
        if (leak_count < 100) {
            leaked_memory[leak_count++] = ptr;
        }
    }
}

void leak_memory_large() {
    void *ptr = malloc(LEAK_SIZE * 10);
    if (ptr) {
        memset(ptr, 'B', LEAK_SIZE * 10);
        // 故意不释放
        if (leak_count < 100) {
            leaked_memory[leak_count++] = ptr;
        }
    }
}

void no_leak_memory() {
    void *ptr = malloc(LEAK_SIZE);
    if (ptr) {
        memset(ptr, 'C', LEAK_SIZE);
        free(ptr);  // 正确释放
    }
}

int main(int argc, char *argv[]) {
    int duration = 30;  // 默认运行 30 秒
    int leak_interval = 2;  // 每 2 秒泄漏一次
    int i;

    if (argc > 1) {
        duration = atoi(argv[1]);
    }
    if (argc > 2) {
        leak_interval = atoi(argv[2]);
    }

    printf("Memory Leaker - 内存泄漏模拟程序\n");
    printf("运行时长: %d 秒\n", duration);
    printf("泄漏间隔: %d 秒\n", duration);
    printf("PID: %d\n", getpid());
    printf("\n");

    printf("程序将故意泄漏内存用于测试 memleak 工具\n");
    printf("在另一个终端运行:\n");
    printf("  sudo memleak -p %d\n", getpid());
    printf("  sudo memleak -p %d -a 5  # 每 5 秒报告一次\n\n", getpid());

    for (i = 0; i < duration / leak_interval; i++) {
        printf("[%d/%d] ", i + 1, duration / leak_interval);

        // 小泄漏
        leak_memory_small();
        printf("✗ 泄漏 %d bytes ", LEAK_SIZE);

        // 大泄漏
        leak_memory_large();
        printf("✗ 泄漏 %d bytes ", LEAK_SIZE * 10);

        // 正常分配和释放（不泄漏）
        no_leak_memory();
        printf("✓ 正常分配释放 %d bytes\n", LEAK_SIZE);

        printf("   当前累计泄漏: %d bytes\n\n", leak_count * LEAK_SIZE * 11 / 10);

        sleep(leak_interval);
    }

    printf("\n完成！\n");
    printf("总泄漏内存: ~%d KB\n", leak_count * LEAK_SIZE * 11 / 1024 / 10);
    printf("程序将继续运行 10 秒以便查看 memleak 结果...\n");

    sleep(10);

    // 可选：在退出前释放部分内存
    printf("\n释放部分泄漏的内存...\n");
    for (i = 0; i < leak_count / 2; i++) {
        if (leaked_memory[i]) {
            free(leaked_memory[i]);
            leaked_memory[i] = NULL;
        }
    }

    printf("程序退出\n");
    return 0;
}
