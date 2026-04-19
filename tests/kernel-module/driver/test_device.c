/*
 * test_device.c - 创建虚拟 platform 设备用于测试
 *
 * 配合 test_driver.c 使用，模拟设备的绑定/解绑
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>

#define DRIVER_NAME "test_driver"
#define DEVICE_COUNT 2

static struct platform_device *test_devices[DEVICE_COUNT];

static int __init test_device_init(void)
{
    int i, ret;

    pr_info("test_device: Creating %d platform devices\n", DEVICE_COUNT);

    for (i = 0; i < DEVICE_COUNT; i++) {
        test_devices[i] = platform_device_alloc(DRIVER_NAME, i);
        if (!test_devices[i]) {
            pr_err("test_device: Failed to allocate device %d\n", i);
            ret = -ENOMEM;
            goto fail;
        }

        ret = platform_device_add(test_devices[i]);
        if (ret) {
            pr_err("test_device: Failed to add device %d\n", i);
            platform_device_put(test_devices[i]);
            goto fail;
        }

        pr_info("test_device: Created device %d\n", i);
    }

    pr_info("test_device: All devices created successfully\n");
    return 0;

fail:
    while (--i >= 0) {
        platform_device_unregister(test_devices[i]);
    }
    return ret;
}

static void __exit test_device_exit(void)
{
    int i;

    pr_info("test_device: Removing platform devices\n");

    for (i = 0; i < DEVICE_COUNT; i++) {
        platform_device_unregister(test_devices[i]);
        pr_info("test_device: Removed device %d\n", i);
    }

    pr_info("test_device: All devices removed\n");
}

module_init(test_device_init);
module_exit(test_device_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Testing Project");
MODULE_DESCRIPTION("Test platform devices");
MODULE_VERSION("1.0");
