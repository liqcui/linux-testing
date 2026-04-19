/*
 * memory_leak.c - 内存泄漏示例程序
 * 演示各种类型的内存泄漏以供Valgrind检测
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* 简单内存泄漏 */
void simple_leak(void)
{
    char *ptr = malloc(100);
    sprintf(ptr, "This memory will be leaked");
    printf("Created leak: %s\n", ptr);
    /* 忘记free(ptr) - 内存泄漏! */
}

/* 循环中的内存泄漏 */
void loop_leak(int count)
{
    for (int i = 0; i < count; i++) {
        char *ptr = malloc(1024);
        sprintf(ptr, "Leak %d", i);
        /* 每次循环都泄漏1KB */
    }
    printf("Loop leak: allocated %d KB\n", count);
}

/* 条件内存泄漏 */
void conditional_leak(int condition)
{
    char *ptr = malloc(200);

    if (condition) {
        free(ptr);
        printf("Memory freed (no leak)\n");
    } else {
        printf("Memory not freed (leak!)\n");
        /* 如果condition为0，内存泄漏 */
    }
}

/* 结构体内存泄漏 */
typedef struct {
    char *name;
    int *data;
} MyStruct;

void struct_leak(void)
{
    MyStruct *s = malloc(sizeof(MyStruct));
    s->name = malloc(50);
    s->data = malloc(100 * sizeof(int));

    strcpy(s->name, "Test Structure");

    /* 只释放了结构体，忘记释放内部指针 */
    free(s);
    /* 应该先free(s->name)和free(s->data) */
}

/* 重复释放 */
void double_free(void)
{
    char *ptr = malloc(100);
    free(ptr);
    /* 危险: 重复释放同一块内存 */
    /* free(ptr); */ /* 取消注释会导致崩溃 */
    printf("Single free (safe)\n");
}

/* 使用已释放的内存 */
void use_after_free(void)
{
    char *ptr = malloc(100);
    strcpy(ptr, "Hello");
    free(ptr);

    /* 危险: 使用已释放的内存 */
    /* printf("After free: %s\n", ptr); */ /* 取消注释是未定义行为 */
    printf("Avoided use-after-free\n");
}

/* 数组越界 */
void array_overflow(void)
{
    int *arr = malloc(10 * sizeof(int));

    for (int i = 0; i < 10; i++) {
        arr[i] = i;
    }

    /* 危险: 越界访问 */
    /* arr[10] = 100; */ /* 取消注释会写入无效内存 */

    free(arr);
    printf("Array access (no overflow)\n");
}

/* 未初始化内存读取 */
void uninitialized_read(void)
{
    int *ptr = malloc(sizeof(int));

    /* 危险: 读取未初始化的内存 */
    /* printf("Uninitialized value: %d\n", *ptr); */ /* 取消注释会读取随机值 */

    *ptr = 42;  /* 正确: 先初始化 */
    printf("Initialized value: %d\n", *ptr);
    free(ptr);
}

/* 内存池泄漏模拟 */
void memory_pool_leak(void)
{
    #define POOL_SIZE 10
    char *pool[POOL_SIZE];

    /* 分配内存池 */
    for (int i = 0; i < POOL_SIZE; i++) {
        pool[i] = malloc(512);
        sprintf(pool[i], "Pool item %d", i);
    }

    /* 只释放部分内存 */
    for (int i = 0; i < POOL_SIZE / 2; i++) {
        free(pool[i]);
    }

    /* 剩余一半内存泄漏 */
    printf("Pool leak: %d items not freed\n", POOL_SIZE / 2);
}

/* 正确的内存管理示例 */
void correct_usage(void)
{
    char *ptr1 = malloc(100);
    char *ptr2 = malloc(200);

    if (ptr1) {
        strcpy(ptr1, "Correctly managed");
        printf("Ptr1: %s\n", ptr1);
        free(ptr1);
    }

    if (ptr2) {
        strcpy(ptr2, "Also correctly managed");
        printf("Ptr2: %s\n", ptr2);
        free(ptr2);
    }

    printf("Correct memory management - no leaks\n");
}

/* 递归分配（可能导致栈溢出和内存泄漏） */
void recursive_alloc(int depth)
{
    if (depth <= 0) return;

    char *ptr = malloc(1024);
    sprintf(ptr, "Recursion depth %d", depth);

    /* 递归但不释放内存 */
    recursive_alloc(depth - 1);

    /* free(ptr); */ /* 如果取消注释，没有泄漏 */
}

int main(int argc, char *argv[])
{
    printf("========================================\n");
    printf("Memory Leak Demonstration Program\n");
    printf("========================================\n");
    printf("This program demonstrates various memory issues\n");
    printf("Run with Valgrind to detect them:\n");
    printf("  valgrind --leak-check=full ./memory_leak\n");
    printf("\n");

    /* 演示各种内存问题 */

    printf("1. Simple leak...\n");
    simple_leak();

    printf("\n2. Loop leak...\n");
    loop_leak(10);

    printf("\n3. Conditional leak (leak case)...\n");
    conditional_leak(0);

    printf("\n4. Conditional leak (no leak case)...\n");
    conditional_leak(1);

    printf("\n5. Struct leak...\n");
    struct_leak();

    printf("\n6. Double free (safe)...\n");
    double_free();

    printf("\n7. Use after free (safe)...\n");
    use_after_free();

    printf("\n8. Array overflow (safe)...\n");
    array_overflow();

    printf("\n9. Uninitialized read (safe)...\n");
    uninitialized_read();

    printf("\n10. Memory pool leak...\n");
    memory_pool_leak();

    printf("\n11. Correct usage...\n");
    correct_usage();

    printf("\n12. Recursive allocation leak...\n");
    recursive_alloc(5);

    printf("\n========================================\n");
    printf("Program completed\n");
    printf("========================================\n");
    printf("\n");
    printf("Expected Valgrind findings:\n");
    printf("  - Definitely lost: ~17 KB\n");
    printf("  - Indirectly lost: ~5 KB\n");
    printf("  - Multiple allocation sites\n");
    printf("\n");

    /* 故意不释放一些内存，以便Valgrind检测 */

    return 0;
}
