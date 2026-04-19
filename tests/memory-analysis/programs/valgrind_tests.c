/*
 * valgrind_tests.c - Valgrind综合测试程序
 * 演示Valgrind可检测的各种内存问题
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 测试1: 内存泄漏 */
void test_memory_leak(void)
{
    printf("\n[TEST 1] Memory Leak\n");
    char *leaked = malloc(100);
    strcpy(leaked, "This will leak");
    /* 忘记free(leaked) */
}

/* 测试2: 无效读取 */
void test_invalid_read(void)
{
    printf("\n[TEST 2] Invalid Read\n");
    int *arr = malloc(10 * sizeof(int));

    for (int i = 0; i < 10; i++) {
        arr[i] = i;
    }

    /* 读取越界 - Valgrind会检测 */
    /* printf("Invalid read: %d\n", arr[10]); */

    free(arr);
    printf("Skipped invalid read to avoid crash\n");
}

/* 测试3: 无效写入 */
void test_invalid_write(void)
{
    printf("\n[TEST 3] Invalid Write\n");
    int *arr = malloc(10 * sizeof(int));

    /* 写入越界 - Valgrind会检测 */
    /* arr[10] = 100; */

    free(arr);
    printf("Skipped invalid write to avoid corruption\n");
}

/* 测试4: 使用未初始化的值 */
void test_uninitialized_value(void)
{
    printf("\n[TEST 4] Uninitialized Value\n");
    int x;
    /* 使用未初始化的变量 - Valgrind会警告 */
    /* if (x == 10) {
        printf("Unlikely\n");
    } */

    x = 10;  /* 正确初始化 */
    printf("Initialized value: %d\n", x);
}

/* 测试5: 无效释放 */
void test_invalid_free(void)
{
    printf("\n[TEST 5] Invalid Free\n");
    int stack_var = 10;

    /* 尝试释放栈变量 - 错误! */
    /* free(&stack_var); */

    printf("Avoided invalid free\n");
}

/* 测试6: 重复释放 */
void test_double_free(void)
{
    printf("\n[TEST 6] Double Free\n");
    char *ptr = malloc(100);
    free(ptr);

    /* 重复释放 - 严重错误! */
    /* free(ptr); */

    printf("Avoided double free\n");
}

/* 测试7: 使用已释放的内存 */
void test_use_after_free(void)
{
    printf("\n[TEST 7] Use After Free\n");
    char *ptr = malloc(100);
    strcpy(ptr, "Hello");
    free(ptr);

    /* 使用已释放的内存 - 未定义行为! */
    /* printf("After free: %s\n", ptr); */

    printf("Avoided use-after-free\n");
}

/* 测试8: 内存重叠 */
void test_overlapping_memcpy(void)
{
    printf("\n[TEST 8] Overlapping memcpy\n");
    char buffer[100];
    strcpy(buffer, "Hello World");

    /* 重叠的memcpy - 应该使用memmove */
    /* memcpy(buffer + 5, buffer, 10); */

    memmove(buffer + 5, buffer, 10);  /* 正确使用memmove */
    printf("Used memmove correctly\n");
}

/* 测试9: 条件跳转依赖未初始化值 */
void test_conditional_jump(void)
{
    printf("\n[TEST 9] Conditional Jump on Uninitialized\n");
    int x;

    /* 条件判断依赖未初始化值 */
    /* if (x > 0) {
        printf("Positive\n");
    } */

    x = 10;  /* 正确初始化 */
    if (x > 0) {
        printf("Positive (initialized)\n");
    }
}

/* 测试10: 内存分配失败处理 */
void test_malloc_failure(void)
{
    printf("\n[TEST 10] Malloc Failure Handling\n");

    /* 尝试分配巨大内存（可能失败） */
    size_t huge_size = (size_t)1024 * 1024 * 1024 * 1024; /* 1 TB */
    void *ptr = malloc(huge_size);

    if (ptr == NULL) {
        printf("Malloc failed as expected for huge allocation\n");
    } else {
        printf("Unexpected success\n");
        free(ptr);
    }

    /* 正确处理失败 */
    ptr = malloc(1024);
    if (ptr != NULL) {
        printf("Normal allocation succeeded\n");
        free(ptr);
    }
}

/* 测试11: realloc问题 */
void test_realloc_issues(void)
{
    printf("\n[TEST 11] Realloc Issues\n");

    char *ptr = malloc(10);
    strcpy(ptr, "Short");

    char *old_ptr = ptr;
    ptr = realloc(ptr, 100);

    if (ptr != NULL) {
        /* 不应该使用old_ptr，它可能已失效 */
        /* printf("Old: %s\n", old_ptr); */

        strcpy(ptr, "Longer string after realloc");
        printf("New: %s\n", ptr);
        free(ptr);
    }
}

/* 测试12: 字符串操作越界 */
void test_string_overflow(void)
{
    printf("\n[TEST 12] String Overflow\n");

    char buffer[10];

    /* strcpy可能越界 - 危险! */
    /* strcpy(buffer, "This string is too long"); */

    /* 使用安全的版本 */
    strncpy(buffer, "Safe", sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    printf("Safe string: %s\n", buffer);
}

/* 测试13: 堆缓冲区溢出 */
void test_heap_overflow(void)
{
    printf("\n[TEST 13] Heap Overflow\n");

    char *buffer = malloc(10);

    /* 写入超过分配的大小 */
    /* strcpy(buffer, "This is way too long for the buffer"); */

    strncpy(buffer, "Short", 9);
    buffer[9] = '\0';
    printf("Safe heap write: %s\n", buffer);

    free(buffer);
}

/* 测试14: 栈缓冲区溢出 */
void test_stack_overflow(void)
{
    printf("\n[TEST 14] Stack Overflow\n");

    char buffer[10];

    /* 栈溢出 - 危险! */
    /* char large[100000000]; */  /* 巨大的栈数组 */

    /* 使用堆代替 */
    char *large = malloc(1024);
    if (large) {
        printf("Used heap instead of large stack array\n");
        free(large);
    }
}

/* 测试15: 正确的内存管理 */
void test_correct_usage(void)
{
    printf("\n[TEST 15] Correct Memory Management\n");

    /* 分配 */
    char *ptr = malloc(100);
    if (ptr == NULL) {
        fprintf(stderr, "Allocation failed\n");
        return;
    }

    /* 使用 */
    strncpy(ptr, "Correctly managed memory", 99);
    ptr[99] = '\0';
    printf("Data: %s\n", ptr);

    /* 释放 */
    free(ptr);
    ptr = NULL;  /* 避免悬挂指针 */

    printf("Correct: allocated, used, freed, nulled\n");
}

int main(int argc, char *argv[])
{
    printf("========================================\n");
    printf("Valgrind Comprehensive Test Program\n");
    printf("========================================\n");
    printf("\n");
    printf("Run with Valgrind:\n");
    printf("  valgrind --leak-check=full \\\n");
    printf("           --show-leak-kinds=all \\\n");
    printf("           --track-origins=yes \\\n");
    printf("           --verbose \\\n");
    printf("           ./valgrind_tests\n");
    printf("\n");

    /* 运行所有测试 */
    test_memory_leak();
    test_invalid_read();
    test_invalid_write();
    test_uninitialized_value();
    test_invalid_free();
    test_double_free();
    test_use_after_free();
    test_overlapping_memcpy();
    test_conditional_jump();
    test_malloc_failure();
    test_realloc_issues();
    test_string_overflow();
    test_heap_overflow();
    test_stack_overflow();
    test_correct_usage();

    printf("\n========================================\n");
    printf("All tests completed\n");
    printf("========================================\n");
    printf("\n");
    printf("Valgrind should report:\n");
    printf("  - 1 block definitely lost (test_memory_leak)\n");
    printf("  - Possibly several warnings about skipped dangerous operations\n");
    printf("\n");

    return 0;
}
