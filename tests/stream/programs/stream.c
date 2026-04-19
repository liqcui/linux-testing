/*-----------------------------------------------------------------------*/
/* STREAM Benchmark Implementation                                       */
/*                                                                       */
/* 基于 STREAM 2 的简化实现                                              */
/* 测试内存带宽：Copy, Scale, Add, Triad                                */
/*-----------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>
#include <limits.h>
#include <time.h>
#include <sys/time.h>

#ifdef _OPENMP
#include <omp.h>
#endif

/* 数组大小 - 默认10M元素 (约80MB，超过大多数L3缓存) */
#ifndef STREAM_ARRAY_SIZE
#define STREAM_ARRAY_SIZE 10000000
#endif

/* 重复次数 */
#ifndef NTIMES
#define NTIMES 10
#endif

/* 偏移量避免缓存行冲突 */
#ifndef OFFSET
#define OFFSET 0
#endif

/* 数据类型 */
#define STREAM_TYPE double

/* 静态数组 */
static STREAM_TYPE a[STREAM_ARRAY_SIZE+OFFSET];
static STREAM_TYPE b[STREAM_ARRAY_SIZE+OFFSET];
static STREAM_TYPE c[STREAM_ARRAY_SIZE+OFFSET];

/* 时间统计 */
static double avgtime[4] = {0}, maxtime[4] = {0}, mintime[4] = {4, DBL_MAX, DBL_MAX, DBL_MAX, DBL_MAX};

/* 标签 */
static char *label[4] = {"Copy:      ", "Scale:     ", "Add:       ", "Triad:     "};

/* 每次操作的字节数 */
static double bytes[4] = {
    2 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,  /* Copy:  a = b */
    2 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,  /* Scale: a = q*b */
    3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,  /* Add:   a = b+c */
    3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE   /* Triad: a = b+q*c */
};

/* 函数声明 */
extern double mysecond();
extern void checkSTREAMresults();

int main()
{
    int quantum, checktick();
    int BytesPerWord;
    int k;
    ssize_t j;
    STREAM_TYPE scalar;
    double t, times[4][NTIMES];

    /* 打印基本信息 */
    printf("-------------------------------------------------------------\n");
    printf("STREAM Benchmark - Memory Bandwidth Test\n");
    printf("-------------------------------------------------------------\n");
    BytesPerWord = sizeof(STREAM_TYPE);
    printf("This system uses %d bytes per array element.\n", BytesPerWord);

    printf("-------------------------------------------------------------\n");
    printf("Array size = %llu (elements), Offset = %d (elements)\n",
           (unsigned long long) STREAM_ARRAY_SIZE, OFFSET);
    printf("Memory per array = %.1f MiB (= %.1f GiB).\n",
           BytesPerWord * ((double) STREAM_ARRAY_SIZE / 1024.0/1024.0),
           BytesPerWord * ((double) STREAM_ARRAY_SIZE / 1024.0/1024.0/1024.0));
    printf("Total memory required = %.1f MiB (= %.1f GiB).\n",
           (3.0 * BytesPerWord) * ((double) STREAM_ARRAY_SIZE / 1024.0/1024.0),
           (3.0 * BytesPerWord) * ((double) STREAM_ARRAY_SIZE / 1024.0/1024.0/1024.0));
    printf("Each kernel will be executed %d times.\n", NTIMES);

#ifdef _OPENMP
    printf("Number of Threads requested = %d\n", omp_get_max_threads());
#else
    printf("Number of Threads = 1 (OpenMP not enabled)\n");
#endif

    /* 检查时钟精度 */
    printf("-------------------------------------------------------------\n");
    quantum = checktick();
    if (quantum >= 1)
        printf("Your clock granularity/precision appears to be %d microseconds.\n", quantum);
    else {
        printf("Your clock granularity appears to be less than one microsecond.\n");
        quantum = 1;
    }

    /* 初始化数组 */
    printf("Initializing arrays...\n");
#ifdef _OPENMP
#pragma omp parallel for
#endif
    for (j=0; j<STREAM_ARRAY_SIZE; j++) {
        a[j] = 1.0;
        b[j] = 2.0;
        c[j] = 0.0;
    }

    printf("-------------------------------------------------------------\n");

    /* 主测试循环 */
    scalar = 3.0;
    for (k=0; k<NTIMES; k++) {
        /* Copy: a = b */
        times[0][k] = mysecond();
#ifdef _OPENMP
#pragma omp parallel for
#endif
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            a[j] = b[j];
        times[0][k] = mysecond() - times[0][k];

        /* Scale: a = scalar * b */
        times[1][k] = mysecond();
#ifdef _OPENMP
#pragma omp parallel for
#endif
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            a[j] = scalar * b[j];
        times[1][k] = mysecond() - times[1][k];

        /* Add: a = b + c */
        times[2][k] = mysecond();
#ifdef _OPENMP
#pragma omp parallel for
#endif
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            a[j] = b[j] + c[j];
        times[2][k] = mysecond() - times[2][k];

        /* Triad: a = b + scalar * c */
        times[3][k] = mysecond();
#ifdef _OPENMP
#pragma omp parallel for
#endif
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            a[j] = b[j] + scalar * c[j];
        times[3][k] = mysecond() - times[3][k];
    }

    /* 计算统计数据 */
    for (k=1; k<NTIMES; k++) { /* 跳过第一次（预热） */
        for (j=0; j<4; j++) {
            avgtime[j] += times[j][k];
            mintime[j] = (mintime[j] < times[j][k]) ? mintime[j] : times[j][k];
            maxtime[j] = (maxtime[j] > times[j][k]) ? maxtime[j] : times[j][k];
        }
    }

    /* 打印结果 */
    printf("Function    Best Rate MB/s  Avg time     Min time     Max time\n");
    for (j=0; j<4; j++) {
        avgtime[j] = avgtime[j]/(double)(NTIMES-1);
        printf("%s%12.1f  %11.6f  %11.6f  %11.6f\n", label[j],
               1.0E-06 * bytes[j]/mintime[j],
               avgtime[j],
               mintime[j],
               maxtime[j]);
    }
    printf("-------------------------------------------------------------\n");

    /* 验证结果 */
    checkSTREAMresults();
    printf("-------------------------------------------------------------\n");

    return 0;
}

/* 高精度计时器 */
double mysecond()
{
    struct timeval tp;
    gettimeofday(&tp, NULL);
    return ((double) tp.tv_sec + (double) tp.tv_usec * 1.e-6);
}

/* 检查时钟精度 */
int checktick()
{
    int i, minDelta, Delta;
    double t1, t2, timesfound[20];

    for (i = 0; i < 20; i++) {
        t1 = mysecond();
        while (((t2=mysecond()) - t1) < 1.0E-6)
            ;
        timesfound[i] = t1 = t2;
    }

    minDelta = 1000000;
    for (i = 1; i < 20; i++) {
        Delta = (int)(1.0E6 * (timesfound[i]-timesfound[i-1]));
        minDelta = (minDelta < Delta) ? minDelta : Delta;
    }

    return(minDelta);
}

/* 验证计算结果 */
void checkSTREAMresults()
{
    STREAM_TYPE aj, bj, cj, scalar;
    STREAM_TYPE aSumErr, bSumErr, cSumErr;
    STREAM_TYPE aAvgErr, bAvgErr, cAvgErr;
    double epsilon;
    ssize_t j;
    int k, ierr, err;

    /* 根据操作次数重现最终值 */
    aj = 1.0;
    bj = 2.0;
    cj = 0.0;
    aj = 2.0E0 * aj;

    scalar = 3.0;
    for (k=0; k<NTIMES; k++) {
        cj = aj;
        bj = scalar * cj;
        cj = aj + bj;
        aj = bj + scalar * cj;
    }

    /* 累积误差 */
    aSumErr = 0.0;
    bSumErr = 0.0;
    cSumErr = 0.0;
    for (j=0; j<STREAM_ARRAY_SIZE; j++) {
        aSumErr += (a[j] - aj) * (a[j] - aj);
        bSumErr += (b[j] - bj) * (b[j] - bj);
        cSumErr += (c[j] - cj) * (c[j] - cj);
    }
    aAvgErr = aSumErr / (STREAM_TYPE) STREAM_ARRAY_SIZE;
    bAvgErr = bSumErr / (STREAM_TYPE) STREAM_ARRAY_SIZE;
    cAvgErr = cSumErr / (STREAM_TYPE) STREAM_ARRAY_SIZE;

    epsilon = 1.e-13;

    err = 0;
    if (aAvgErr > epsilon) {
        err++;
        printf("Failed Validation on array a[], AvgRelAbsErr > epsilon (%e)\n", epsilon);
        printf("     Expected Value: %e, AvgAbsErr: %e, AvgRelAbsErr: %e\n", aj, aAvgErr, aAvgErr/aj);
        ierr = 0;
        for (j=0; j<STREAM_ARRAY_SIZE; j++) {
            if ((a[j] - aj) * (a[j] - aj) > epsilon) {
                ierr++;
#ifdef VERBOSE
                if (ierr < 10) {
                    printf("         array a: index: %ld, expected: %e, observed: %e\n",
                           j, aj, a[j]);
                }
#endif
            }
        }
        printf("     For array a[], %d errors were found.\n", ierr);
    }
    if (bAvgErr > epsilon) {
        err++;
        printf("Failed Validation on array b[], AvgRelAbsErr > epsilon (%e)\n", epsilon);
        printf("     Expected Value: %e, AvgAbsErr: %e, AvgRelAbsErr: %e\n", bj, bAvgErr, bAvgErr/bj);
        ierr = 0;
        for (j=0; j<STREAM_ARRAY_SIZE; j++) {
            if ((b[j] - bj) * (b[j] - bj) > epsilon) {
                ierr++;
#ifdef VERBOSE
                if (ierr < 10) {
                    printf("         array b: index: %ld, expected: %e, observed: %e\n",
                           j, bj, b[j]);
                }
#endif
            }
        }
        printf("     For array b[], %d errors were found.\n", ierr);
    }
    if (cAvgErr > epsilon) {
        err++;
        printf("Failed Validation on array c[], AvgRelAbsErr > epsilon (%e)\n", epsilon);
        printf("     Expected Value: %e, AvgAbsErr: %e, AvgRelAbsErr: %e\n", cj, cAvgErr, cAvgErr/cj);
        ierr = 0;
        for (j=0; j<STREAM_ARRAY_SIZE; j++) {
            if ((c[j] - cj) * (c[j] - cj) > epsilon) {
                ierr++;
#ifdef VERBOSE
                if (ierr < 10) {
                    printf("         array c: index: %ld, expected: %e, observed: %e\n",
                           j, cj, c[j]);
                }
#endif
            }
        }
        printf("     For array c[], %d errors were found.\n", ierr);
    }
    if (err == 0) {
        printf("Solution Validates: avg error less than %e on all three arrays\n", epsilon);
    }
}
