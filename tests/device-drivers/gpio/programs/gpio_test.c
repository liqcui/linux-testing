/*
 * gpio_test.c - GPIO测试程序
 *
 * 使用字符设备接口测试GPIO功能
 * 支持读取、写入和中断监控
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <errno.h>
#include <sys/stat.h>
#include <getopt.h>
#include <time.h>

#define GPIO_BASE_PATH "/sys/class/gpio"

static int gpio_num = -1;
static char *operation = NULL;
static int value = -1;
static int verbose = 0;
static int monitor_time = 10;  // 默认监控10秒

static void print_usage(const char *prog)
{
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -g --gpio     GPIO编号 (必需)\n");
    printf("  -o --op       操作: export, unexport, read, write, monitor\n");
    printf("  -v --value    写入值: 0 or 1\n");
    printf("  -d --dir      方向: in, out\n");
    printf("  -e --edge     边沿触发: none, rising, falling, both\n");
    printf("  -t --time     监控时间 (秒，默认10)\n");
    printf("  -V --verbose  详细输出\n");
    printf("  -h --help     显示帮助\n");
    printf("\n");
    printf("Examples:\n");
    printf("  %s -g 17 -o export          # 导出GPIO17\n", prog);
    printf("  %s -g 17 -d out             # 设置为输出\n", prog);
    printf("  %s -g 17 -o write -v 1      # 写入高电平\n", prog);
    printf("  %s -g 17 -o read            # 读取状态\n", prog);
    printf("  %s -g 17 -e both -o monitor # 监控中断\n", prog);
}

static void parse_opts(int argc, char *argv[])
{
    static const struct option lopts[] = {
        { "gpio",    1, 0, 'g' },
        { "op",      1, 0, 'o' },
        { "value",   1, 0, 'v' },
        { "dir",     1, 0, 'd' },
        { "edge",    1, 0, 'e' },
        { "time",    1, 0, 't' },
        { "verbose", 0, 0, 'V' },
        { "help",    0, 0, 'h' },
        { NULL, 0, 0, 0 },
    };
    int c;
    char *direction = NULL;
    char *edge = NULL;

    while ((c = getopt_long(argc, argv, "g:o:v:d:e:t:Vh",
                lopts, NULL)) != -1) {
        switch (c) {
        case 'g':
            gpio_num = atoi(optarg);
            break;
        case 'o':
            operation = optarg;
            break;
        case 'v':
            value = atoi(optarg);
            break;
        case 'd':
            direction = optarg;
            break;
        case 'e':
            edge = optarg;
            break;
        case 't':
            monitor_time = atoi(optarg);
            break;
        case 'V':
            verbose = 1;
            break;
        case 'h':
            print_usage(argv[0]);
            exit(0);
        default:
            print_usage(argv[0]);
            exit(1);
        }
    }

    if (gpio_num < 0) {
        fprintf(stderr, "错误: 必须指定GPIO编号 (-g)\n");
        print_usage(argv[0]);
        exit(1);
    }

    // 处理方向设置
    if (direction) {
        char path[256];
        snprintf(path, sizeof(path), "%s/gpio%d/direction",
                 GPIO_BASE_PATH, gpio_num);

        FILE *fp = fopen(path, "w");
        if (!fp) {
            perror("设置方向失败");
            exit(1);
        }
        fprintf(fp, "%s", direction);
        fclose(fp);

        if (verbose) {
            printf("✓ GPIO%d 方向设置为: %s\n", gpio_num, direction);
        }
    }

    // 处理边沿设置
    if (edge) {
        char path[256];
        snprintf(path, sizeof(path), "%s/gpio%d/edge",
                 GPIO_BASE_PATH, gpio_num);

        FILE *fp = fopen(path, "w");
        if (!fp) {
            perror("设置边沿触发失败");
            exit(1);
        }
        fprintf(fp, "%s", edge);
        fclose(fp);

        if (verbose) {
            printf("✓ GPIO%d 边沿触发设置为: %s\n", gpio_num, edge);
        }
    }
}

static int gpio_export(int gpio)
{
    FILE *fp;
    char path[256];

    // 检查是否已导出
    snprintf(path, sizeof(path), "%s/gpio%d", GPIO_BASE_PATH, gpio);
    if (access(path, F_OK) == 0) {
        if (verbose) {
            printf("GPIO%d 已经导出\n", gpio);
        }
        return 0;
    }

    fp = fopen(GPIO_BASE_PATH "/export", "w");
    if (!fp) {
        perror("打开export失败");
        return -1;
    }

    fprintf(fp, "%d", gpio);
    fclose(fp);

    // 等待sysfs创建
    usleep(100000);

    printf("✓ GPIO%d 已导出\n", gpio);
    return 0;
}

static int gpio_unexport(int gpio)
{
    FILE *fp;

    fp = fopen(GPIO_BASE_PATH "/unexport", "w");
    if (!fp) {
        perror("打开unexport失败");
        return -1;
    }

    fprintf(fp, "%d", gpio);
    fclose(fp);

    printf("✓ GPIO%d 已取消导出\n", gpio);
    return 0;
}

static int gpio_read(int gpio)
{
    char path[256];
    FILE *fp;
    int val;

    snprintf(path, sizeof(path), "%s/gpio%d/value", GPIO_BASE_PATH, gpio);

    fp = fopen(path, "r");
    if (!fp) {
        perror("读取GPIO失败");
        return -1;
    }

    if (fscanf(fp, "%d", &val) != 1) {
        fprintf(stderr, "读取GPIO值失败\n");
        fclose(fp);
        return -1;
    }

    fclose(fp);

    printf("GPIO%d 值: %d\n", gpio, val);
    return val;
}

static int gpio_write(int gpio, int val)
{
    char path[256];
    FILE *fp;

    if (val != 0 && val != 1) {
        fprintf(stderr, "错误: GPIO值必须是0或1\n");
        return -1;
    }

    snprintf(path, sizeof(path), "%s/gpio%d/value", GPIO_BASE_PATH, gpio);

    fp = fopen(path, "w");
    if (!fp) {
        perror("打开GPIO失败");
        return -1;
    }

    fprintf(fp, "%d", val);
    fclose(fp);

    printf("✓ GPIO%d 设置为: %d\n", gpio, val);
    return 0;
}

static int gpio_monitor(int gpio, int timeout)
{
    char path[256];
    int fd;
    struct pollfd pfd;
    char buf[8];
    int ret;
    int count = 0;
    time_t start_time, current_time;

    snprintf(path, sizeof(path), "%s/gpio%d/value", GPIO_BASE_PATH, gpio);

    fd = open(path, O_RDONLY);
    if (fd < 0) {
        perror("打开GPIO失败");
        return -1;
    }

    // 初始读取
    read(fd, buf, sizeof(buf));

    printf("监控GPIO%d中断 (超时: %d 秒)...\n", gpio, timeout);
    printf("按Ctrl+C停止监控\n\n");

    pfd.fd = fd;
    pfd.events = POLLPRI | POLLERR;

    start_time = time(NULL);

    while (1) {
        current_time = time(NULL);
        if (current_time - start_time >= timeout) {
            printf("\n监控超时\n");
            break;
        }

        ret = poll(&pfd, 1, 1000);  // 1秒超时

        if (ret < 0) {
            perror("poll失败");
            break;
        }

        if (ret == 0) {
            // 超时，继续
            continue;
        }

        if (pfd.revents & (POLLPRI | POLLERR)) {
            lseek(fd, 0, SEEK_SET);
            if (read(fd, buf, sizeof(buf)) < 0) {
                perror("读取失败");
                break;
            }

            count++;
            time_t now = time(NULL);
            struct tm *tm_info = localtime(&now);
            char time_str[26];
            strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info);

            printf("[%s] 中断 #%d: GPIO%d = %c\n",
                   time_str, count, gpio, buf[0]);
        }
    }

    close(fd);

    printf("\n总中断次数: %d\n", count);
    printf("平均频率: %.2f 次/秒\n", (float)count / timeout);

    return 0;
}

static int gpio_toggle_test(int gpio, int iterations, int delay_ms)
{
    int i;
    struct timespec start, end;
    double total_time;

    printf("GPIO翻转测试: %d 次迭代，延迟 %d ms\n", iterations, delay_ms);

    clock_gettime(CLOCK_MONOTONIC, &start);

    for (i = 0; i < iterations; i++) {
        gpio_write(gpio, 1);
        usleep(delay_ms * 1000);
        gpio_write(gpio, 0);
        usleep(delay_ms * 1000);

        if ((i + 1) % 100 == 0 && verbose) {
            printf("  完成 %d/%d 次翻转...\n", i + 1, iterations);
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);

    total_time = (end.tv_sec - start.tv_sec) +
                 (end.tv_nsec - start.tv_nsec) / 1e9;

    printf("\n翻转测试结果:\n");
    printf("  迭代次数: %d\n", iterations);
    printf("  总耗时: %.3f 秒\n", total_time);
    printf("  平均频率: %.2f Hz\n", iterations / total_time);

    return 0;
}

int main(int argc, char *argv[])
{
    printf("========================================\n");
    printf("GPIO测试程序\n");
    printf("========================================\n\n");

    parse_opts(argc, argv);

    if (!operation) {
        fprintf(stderr, "错误: 必须指定操作 (-o)\n");
        print_usage(argv[0]);
        return 1;
    }

    if (strcmp(operation, "export") == 0) {
        return gpio_export(gpio_num);
    } else if (strcmp(operation, "unexport") == 0) {
        return gpio_unexport(gpio_num);
    } else if (strcmp(operation, "read") == 0) {
        return (gpio_read(gpio_num) < 0) ? 1 : 0;
    } else if (strcmp(operation, "write") == 0) {
        if (value < 0) {
            fprintf(stderr, "错误: 写操作需要指定值 (-v)\n");
            return 1;
        }
        return gpio_write(gpio_num, value);
    } else if (strcmp(operation, "monitor") == 0) {
        return gpio_monitor(gpio_num, monitor_time);
    } else if (strcmp(operation, "toggle") == 0) {
        return gpio_toggle_test(gpio_num, 100, 10);
    } else {
        fprintf(stderr, "错误: 未知操作: %s\n", operation);
        return 1;
    }

    return 0;
}
