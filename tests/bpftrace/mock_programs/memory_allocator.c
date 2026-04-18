/*
 * memory_allocator.c - 内存分配模拟程序
 * 用于测试 bpftrace 内存分配跟踪
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    int iterations = 10;
    size_t alloc_size = 2097152;  // 2MB
    int i;
    void **ptrs;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    }
    if (argc > 2) {
        alloc_size = atoll(argv[2]);
    }

    printf("Memory Allocator - 内存分配模拟程序\n");
    printf("分配次数: %d\n", iterations);
    printf("每次大小: %zu bytes (%.2f MB)\n", alloc_size, alloc_size / 1048576.0);
    printf("PID: %d\n", getpid());
    printf("\n");

    printf("使用 bpftrace 跟踪大内存分配:\n");
    printf("  sudo bpftrace -e 'uprobe:/lib/x86_64-linux-gnu/libc.so.6:malloc /arg0 > 1048576/ ");
    printf("{ printf(\"%%s malloc(%%d)\\n\", comm, arg0); }'\n");
    printf("  或跟踪本进程:\n");
    printf("  sudo bpftrace -e 'uprobe:/lib/x86_64-linux-gnu/libc.so.6:malloc /pid == %d && arg0 > 1048576/ ", getpid());
    printf("{ printf(\"%%d bytes\\n\", arg0); }'\n\n");

    sleep(3);  // 给时间启动 bpftrace

    // 分配指针数组
    ptrs = malloc(iterations * sizeof(void*));

    printf("开始分配内存...\n");

    for (i = 0; i < iterations; i++) {
        ptrs[i] = malloc(alloc_size);

        if (ptrs[i]) {
            memset(ptrs[i], 0xAA, alloc_size);
            printf("  [%d/%d] 分配 %zu bytes (地址: %p)\n",
                   i + 1, iterations, alloc_size, ptrs[i]);
        } else {
            printf("  [%d/%d] 分配失败！\n", i + 1, iterations);
        }

        sleep(1);  // 慢速分配，便于观察
    }

    printf("\n总共分配: %.2f MB\n", (iterations * alloc_size) / 1048576.0);
    printf("按回车键释放内存...");
    getchar();

    // 释放内存
    printf("释放内存...\n");
    for (i = 0; i < iterations; i++) {
        if (ptrs[i]) {
            free(ptrs[i]);
        }
    }
    free(ptrs);

    printf("完成！\n");

    return 0;
}
