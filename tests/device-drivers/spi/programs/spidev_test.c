/*
 * spidev_test.c - SPI设备测试程序
 *
 * 基于Linux内核的spidev_test.c修改
 * 支持回环测试、性能测试和数据验证
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/types.h>
#include <linux/spi/spidev.h>
#include <getopt.h>
#include <time.h>

#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))

static const char *device = "/dev/spidev0.0";
static uint32_t mode = 0;
static uint8_t bits = 8;
static uint32_t speed = 500000;
static uint16_t delay = 0;
static int verbose = 0;
static int loopback = 0;
static int test_iterations = 1;

// 默认测试数据
static uint8_t default_tx[] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x40, 0x00, 0x00, 0x00, 0x00, 0x95,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xDE, 0xAD, 0xBE, 0xEF, 0xBA, 0xAD,
    0xF0, 0x0D,
};

static void print_usage(const char *prog)
{
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -D --device   设备路径 (默认: /dev/spidev0.0)\n");
    printf("  -s --speed    最大速度 (Hz)\n");
    printf("  -d --delay    延迟 (usec)\n");
    printf("  -b --bits     每字位数\n");
    printf("  -l --loop     回环测试\n");
    printf("  -H --cpha     时钟相位\n");
    printf("  -O --cpol     时钟极性\n");
    printf("  -L --lsb      LSB优先\n");
    printf("  -C --cs-high  片选高电平有效\n");
    printf("  -3 --3wire    SI/SO信号共享\n");
    printf("  -v --verbose  详细输出\n");
    printf("  -n --iterations 测试迭代次数\n");
    printf("  -h --help     显示帮助\n");
}

static void parse_opts(int argc, char *argv[])
{
    static const struct option lopts[] = {
        { "device",     1, 0, 'D' },
        { "speed",      1, 0, 's' },
        { "delay",      1, 0, 'd' },
        { "bits",       1, 0, 'b' },
        { "loop",       0, 0, 'l' },
        { "cpha",       0, 0, 'H' },
        { "cpol",       0, 0, 'O' },
        { "lsb",        0, 0, 'L' },
        { "cs-high",    0, 0, 'C' },
        { "3wire",      0, 0, '3' },
        { "verbose",    0, 0, 'v' },
        { "iterations", 1, 0, 'n' },
        { "help",       0, 0, 'h' },
        { NULL, 0, 0, 0 },
    };
    int c;

    while ((c = getopt_long(argc, argv, "D:s:d:b:lHOLC3vn:h",
                lopts, NULL)) != -1) {
        switch (c) {
        case 'D':
            device = optarg;
            break;
        case 's':
            speed = atoi(optarg);
            break;
        case 'd':
            delay = atoi(optarg);
            break;
        case 'b':
            bits = atoi(optarg);
            break;
        case 'l':
            loopback = 1;
            break;
        case 'H':
            mode |= SPI_CPHA;
            break;
        case 'O':
            mode |= SPI_CPOL;
            break;
        case 'L':
            mode |= SPI_LSB_FIRST;
            break;
        case 'C':
            mode |= SPI_CS_HIGH;
            break;
        case '3':
            mode |= SPI_3WIRE;
            break;
        case 'v':
            verbose = 1;
            break;
        case 'n':
            test_iterations = atoi(optarg);
            break;
        case 'h':
            print_usage(argv[0]);
            exit(0);
        default:
            print_usage(argv[0]);
            exit(1);
        }
    }
}

static void print_buffer(const char *label, uint8_t *buf, int len)
{
    int i;

    printf("%s: ", label);
    for (i = 0; i < len; i++) {
        if (i % 16 == 0)
            printf("\n  ");
        printf("%.2X ", buf[i]);
    }
    printf("\n");
}

static int transfer(int fd, uint8_t *tx, uint8_t *rx, int len)
{
    int ret;
    struct spi_ioc_transfer tr = {
        .tx_buf = (unsigned long)tx,
        .rx_buf = (unsigned long)rx,
        .len = len,
        .delay_usecs = delay,
        .speed_hz = speed,
        .bits_per_word = bits,
    };

    ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
    if (ret < 1) {
        perror("ioctl SPI_IOC_MESSAGE");
        return -1;
    }

    return 0;
}

static int verify_loopback(uint8_t *tx, uint8_t *rx, int len)
{
    int errors = 0;
    int i;

    for (i = 0; i < len; i++) {
        if (tx[i] != rx[i]) {
            if (verbose) {
                printf("  错误 @ 偏移 %d: TX=0x%.2X, RX=0x%.2X\n",
                       i, tx[i], rx[i]);
            }
            errors++;
        }
    }

    return errors;
}

static void run_test(int fd)
{
    int ret;
    int len = ARRAY_SIZE(default_tx);
    uint8_t *rx = malloc(len);
    int iteration;
    int total_errors = 0;
    struct timespec start, end;
    double total_time = 0;

    if (!rx) {
        perror("malloc");
        return;
    }

    printf("\n开始测试...\n");
    printf("  设备: %s\n", device);
    printf("  速度: %u Hz (%u KHz)\n", speed, speed / 1000);
    printf("  位数: %u\n", bits);
    printf("  模式: 0x%x\n", mode);
    printf("  数据长度: %d 字节\n", len);
    printf("  迭代次数: %d\n", test_iterations);
    printf("\n");

    for (iteration = 0; iteration < test_iterations; iteration++) {
        memset(rx, 0, len);

        clock_gettime(CLOCK_MONOTONIC, &start);
        ret = transfer(fd, default_tx, rx, len);
        clock_gettime(CLOCK_MONOTONIC, &end);

        if (ret < 0) {
            printf("迭代 %d: 传输失败\n", iteration + 1);
            continue;
        }

        double elapsed = (end.tv_sec - start.tv_sec) +
                        (end.tv_nsec - start.tv_nsec) / 1e9;
        total_time += elapsed;

        if (verbose || test_iterations == 1) {
            print_buffer("TX", default_tx, len);
            print_buffer("RX", rx, len);
        }

        if (loopback) {
            int errors = verify_loopback(default_tx, rx, len);
            if (errors > 0) {
                printf("迭代 %d: 发现 %d 个错误\n", iteration + 1, errors);
                total_errors += errors;
            } else if (verbose) {
                printf("迭代 %d: 回环验证通过\n", iteration + 1);
            }
        }

        if (verbose) {
            printf("迭代 %d: 耗时 %.6f 秒\n", iteration + 1, elapsed);
        }

        if ((iteration + 1) % 100 == 0) {
            printf("  完成 %d/%d 次迭代...\n", iteration + 1, test_iterations);
        }
    }

    printf("\n测试结果:\n");
    printf("  总迭代次数: %d\n", test_iterations);
    printf("  总耗时: %.6f 秒\n", total_time);
    printf("  平均延迟: %.6f 秒/次\n", total_time / test_iterations);
    printf("  吞吐量: %.2f KB/s\n",
           (len * test_iterations) / total_time / 1024);

    if (loopback) {
        printf("  总错误: %d\n", total_errors);
        if (total_errors == 0) {
            printf("  ✓ 回环测试通过\n");
        } else {
            printf("  ✗ 回环测试失败\n");
        }
    }

    printf("\n");
    free(rx);
}

int main(int argc, char *argv[])
{
    int ret = 0;
    int fd;

    parse_opts(argc, argv);

    printf("========================================\n");
    printf("SPI设备测试程序\n");
    printf("========================================\n");

    fd = open(device, O_RDWR);
    if (fd < 0) {
        perror("打开设备失败");
        printf("\n提示:\n");
        printf("  1. 检查设备是否存在: ls -l %s\n", device);
        printf("  2. 检查权限: sudo chmod 666 %s\n", device);
        printf("  3. 加载spidev模块: sudo modprobe spidev\n");
        return 1;
    }

    // 设置SPI模式
    ret = ioctl(fd, SPI_IOC_WR_MODE32, &mode);
    if (ret == -1) {
        perror("设置SPI模式失败");
        goto out;
    }

    ret = ioctl(fd, SPI_IOC_RD_MODE32, &mode);
    if (ret == -1) {
        perror("读取SPI模式失败");
        goto out;
    }

    // 设置位数
    ret = ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
    if (ret == -1) {
        perror("设置位数失败");
        goto out;
    }

    ret = ioctl(fd, SPI_IOC_RD_BITS_PER_WORD, &bits);
    if (ret == -1) {
        perror("读取位数失败");
        goto out;
    }

    // 设置速度
    ret = ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed);
    if (ret == -1) {
        perror("设置最大速度失败");
        goto out;
    }

    ret = ioctl(fd, SPI_IOC_RD_MAX_SPEED_HZ, &speed);
    if (ret == -1) {
        perror("读取最大速度失败");
        goto out;
    }

    // 运行测试
    run_test(fd);

out:
    close(fd);
    return ret;
}
