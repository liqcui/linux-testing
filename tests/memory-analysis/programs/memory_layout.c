/*
 * memory_layout.c - 内存布局演示程序
 * 用于pmap分析，展示各种内存区域
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

/* 全局变量 - BSS段（未初始化） */
int global_uninit;
int global_array[1000];

/* 全局变量 - Data段（已初始化） */
int global_init = 42;
char global_string[] = "Initialized global data";

/* 只读数据 - Rodata段 */
const char *readonly_string = "This is read-only";
const int readonly_int = 100;

/* 分配不同大小的内存块 */
void allocate_memory_regions(void)
{
    printf("Allocating various memory regions...\n\n");

    /* 堆内存 - 小块分配 */
    printf("1. Small heap allocations (< 128 KB):\n");
    char *small1 = malloc(1024);        /* 1 KB */
    char *small2 = malloc(4096);        /* 4 KB */
    char *small3 = malloc(16384);       /* 16 KB */
    sprintf(small1, "Small allocation 1");
    printf("   - 1 KB at %p\n", (void*)small1);
    printf("   - 4 KB at %p\n", (void*)small2);
    printf("   - 16 KB at %p\n", (void*)small3);

    /* 堆内存 - 大块分配（可能使用mmap） */
    printf("\n2. Large heap allocations (> 128 KB):\n");
    char *large1 = malloc(256 * 1024);  /* 256 KB */
    char *large2 = malloc(1024 * 1024); /* 1 MB */
    char *large3 = malloc(4 * 1024 * 1024); /* 4 MB */
    sprintf(large1, "Large allocation 1");
    printf("   - 256 KB at %p\n", (void*)large1);
    printf("   - 1 MB at %p\n", (void*)large2);
    printf("   - 4 MB at %p\n", (void*)large3);

    /* 直接mmap分配 */
    printf("\n3. Direct mmap allocations:\n");
    void *mmap1 = mmap(NULL, 2 * 1024 * 1024, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    void *mmap2 = mmap(NULL, 8 * 1024 * 1024, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    printf("   - 2 MB mmap at %p\n", mmap1);
    printf("   - 8 MB mmap at %p\n", mmap2);

    /* 栈内存 */
    printf("\n4. Stack memory:\n");
    char stack_array[1024];
    int stack_var = 10;
    sprintf(stack_array, "Stack data");
    printf("   - Stack array at %p\n", (void*)stack_array);
    printf("   - Stack variable at %p\n", (void*)&stack_var);

    /* 显示各段地址 */
    printf("\n5. Memory segments:\n");
    printf("   - Code (text) segment: ~%p (readonly_string)\n", (void*)readonly_string);
    printf("   - Data segment: %p (global_init)\n", (void*)&global_init);
    printf("   - BSS segment: %p (global_uninit)\n", (void*)&global_uninit);
    printf("   - Heap start: ~%p\n", (void*)small1);
    printf("   - Stack: ~%p\n", (void*)&stack_var);

    printf("\n6. Display current process memory map:\n");
    printf("   Run: pmap %d\n", getpid());
    printf("   Or:  cat /proc/%d/maps\n", getpid());

    /* 保持程序运行以便查看pmap */
    printf("\nPress Enter to view pmap output...\n");
    getchar();

    /* 显示pmap */
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "pmap -x %d", getpid());
    printf("\nMemory map (pmap -x):\n");
    printf("=====================================\n");
    system(cmd);

    printf("\nDetailed maps (/proc/%d/maps):\n", getpid());
    printf("=====================================\n");
    snprintf(cmd, sizeof(cmd), "cat /proc/%d/maps", getpid());
    system(cmd);

    /* 显示内存统计 */
    printf("\nMemory statistics (/proc/%d/status):\n", getpid());
    printf("=====================================\n");
    snprintf(cmd, sizeof(cmd), "cat /proc/%d/status | grep -E 'Vm|Rss'", getpid());
    system(cmd);

    /* 清理内存 */
    printf("\nPress Enter to cleanup and exit...\n");
    getchar();

    free(small1);
    free(small2);
    free(small3);
    free(large1);
    free(large2);
    free(large3);
    munmap(mmap1, 2 * 1024 * 1024);
    munmap(mmap2, 8 * 1024 * 1024);
}

/* 演示内存增长 */
void demonstrate_memory_growth(void)
{
    printf("\n========================================\n");
    printf("Demonstrating memory growth\n");
    printf("========================================\n\n");

    printf("Initial state:\n");
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "cat /proc/%d/status | grep VmSize", getpid());
    system(cmd);

    for (int i = 0; i < 5; i++) {
        printf("\nAllocating 10 MB (iteration %d)...\n", i + 1);
        malloc(10 * 1024 * 1024);

        snprintf(cmd, sizeof(cmd), "cat /proc/%d/status | grep VmSize", getpid());
        system(cmd);

        sleep(1);
    }
}

int main(int argc, char *argv[])
{
    printf("========================================\n");
    printf("Memory Layout Demonstration Program\n");
    printf("========================================\n");
    printf("PID: %d\n", getpid());
    printf("\n");

    printf("This program demonstrates:\n");
    printf("  1. Different memory regions (stack, heap, code, data, bss)\n");
    printf("  2. Small vs large allocations\n");
    printf("  3. mmap vs malloc\n");
    printf("  4. Memory layout with pmap\n");
    printf("\n");

    if (argc > 1 && strcmp(argv[1], "growth") == 0) {
        demonstrate_memory_growth();
    } else {
        allocate_memory_regions();
    }

    printf("\nProgram completed.\n");
    return 0;
}
