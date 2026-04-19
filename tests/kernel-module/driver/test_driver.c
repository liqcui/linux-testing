/*
 * test_driver.c - 简单的测试驱动程序
 *
 * 用于测试驱动加载/卸载、设备绑定/解绑、电源管理等
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/pm.h>
#include <linux/cdev.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/uaccess.h>

#define DRIVER_NAME "test_driver"
#define DEVICE_NAME "testdev"

/* 模块参数 */
static int debug_level = 0;
module_param(debug_level, int, 0644);
MODULE_PARM_DESC(debug_level, "Debug output level (0-3)");

/* 设备私有数据 */
struct test_device_data {
    int id;
    char buffer[256];
    size_t buffer_size;
    struct mutex lock;
    int suspend_count;
    int resume_count;
};

/* 字符设备相关 */
static dev_t dev_num;
static struct class *test_class;
static struct cdev test_cdev;

/* 设备计数器 */
static int device_count = 0;

/* 调试宏 */
#define DPRINT(level, fmt, ...) \
    do { \
        if (debug_level >= level) \
            pr_info(DRIVER_NAME ": " fmt, ##__VA_ARGS__); \
    } while (0)

/*
 * 字符设备操作
 */
static int test_open(struct inode *inode, struct file *file)
{
    DPRINT(2, "Device opened\n");
    return 0;
}

static int test_release(struct inode *inode, struct file *file)
{
    DPRINT(2, "Device closed\n");
    return 0;
}

static ssize_t test_read(struct file *file, char __user *buf,
                         size_t count, loff_t *ppos)
{
    char msg[] = "Hello from test_driver!\n";
    size_t len = strlen(msg);

    if (*ppos >= len)
        return 0;

    if (count > len - *ppos)
        count = len - *ppos;

    if (copy_to_user(buf, msg + *ppos, count))
        return -EFAULT;

    *ppos += count;
    DPRINT(2, "Read %zu bytes\n", count);

    return count;
}

static ssize_t test_write(struct file *file, const char __user *buf,
                          size_t count, loff_t *ppos)
{
    DPRINT(2, "Write %zu bytes\n", count);
    return count;
}

static struct file_operations test_fops = {
    .owner = THIS_MODULE,
    .open = test_open,
    .release = test_release,
    .read = test_read,
    .write = test_write,
};

/*
 * Platform 驱动操作
 */
static int test_probe(struct platform_device *pdev)
{
    struct test_device_data *data;

    DPRINT(1, "Probing device: %s\n", pdev->name);

    /* 分配设备私有数据 */
    data = devm_kzalloc(&pdev->dev, sizeof(*data), GFP_KERNEL);
    if (!data)
        return -ENOMEM;

    data->id = device_count++;
    mutex_init(&data->lock);
    sprintf(data->buffer, "Device %d initialized", data->id);
    data->buffer_size = strlen(data->buffer);

    platform_set_drvdata(pdev, data);

    DPRINT(1, "Device %d probed successfully\n", data->id);

    return 0;
}

static int test_remove(struct platform_device *pdev)
{
    struct test_device_data *data = platform_get_drvdata(pdev);

    DPRINT(1, "Removing device %d\n", data->id);

    /* 清理工作 */
    mutex_destroy(&data->lock);
    device_count--;

    DPRINT(1, "Device removed successfully\n");

    return 0;
}

#ifdef CONFIG_PM
/*
 * 电源管理操作
 */
static int test_suspend(struct device *dev)
{
    struct test_device_data *data = dev_get_drvdata(dev);

    DPRINT(1, "Suspending device %d\n", data->id);

    mutex_lock(&data->lock);
    data->suspend_count++;
    /* 保存设备状态 */
    mutex_unlock(&data->lock);

    DPRINT(1, "Device suspended (count: %d)\n", data->suspend_count);

    return 0;
}

static int test_resume(struct device *dev)
{
    struct test_device_data *data = dev_get_drvdata(dev);

    DPRINT(1, "Resuming device %d\n", data->id);

    mutex_lock(&data->lock);
    data->resume_count++;
    /* 恢复设备状态 */
    mutex_unlock(&data->lock);

    DPRINT(1, "Device resumed (count: %d)\n", data->resume_count);

    return 0;
}

#ifdef CONFIG_PM_SLEEP
static int test_freeze(struct device *dev)
{
    DPRINT(1, "Freezing device\n");
    return test_suspend(dev);
}

static int test_thaw(struct device *dev)
{
    DPRINT(1, "Thawing device\n");
    return test_resume(dev);
}

static int test_poweroff(struct device *dev)
{
    DPRINT(1, "Powering off device\n");
    return test_suspend(dev);
}

static int test_restore(struct device *dev)
{
    DPRINT(1, "Restoring device\n");
    return test_resume(dev);
}
#endif /* CONFIG_PM_SLEEP */

#ifdef CONFIG_PM_RUNTIME
static int test_runtime_suspend(struct device *dev)
{
    struct test_device_data *data = dev_get_drvdata(dev);

    DPRINT(2, "Runtime suspend device %d\n", data->id);

    return 0;
}

static int test_runtime_resume(struct device *dev)
{
    struct test_device_data *data = dev_get_drvdata(dev);

    DPRINT(2, "Runtime resume device %d\n", data->id);

    return 0;
}

static int test_runtime_idle(struct device *dev)
{
    DPRINT(3, "Runtime idle\n");
    return -EBUSY; /* 阻止自动挂起，用于测试 */
}
#endif /* CONFIG_PM_RUNTIME */

static const struct dev_pm_ops test_pm_ops = {
#ifdef CONFIG_PM_SLEEP
    .suspend = test_suspend,
    .resume = test_resume,
    .freeze = test_freeze,
    .thaw = test_thaw,
    .poweroff = test_poweroff,
    .restore = test_restore,
#endif
#ifdef CONFIG_PM_RUNTIME
    .runtime_suspend = test_runtime_suspend,
    .runtime_resume = test_runtime_resume,
    .runtime_idle = test_runtime_idle,
#endif
};
#endif /* CONFIG_PM */

/*
 * Platform 驱动定义
 */
static struct platform_driver test_platform_driver = {
    .probe = test_probe,
    .remove = test_remove,
    .driver = {
        .name = DRIVER_NAME,
        .owner = THIS_MODULE,
#ifdef CONFIG_PM
        .pm = &test_pm_ops,
#endif
    },
};

/*
 * 模块初始化
 */
static int __init test_driver_init(void)
{
    int ret;

    pr_info(DRIVER_NAME ": Loading test driver module\n");
    pr_info(DRIVER_NAME ": Debug level: %d\n", debug_level);

    /* 注册字符设备 */
    ret = alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
    if (ret < 0) {
        pr_err(DRIVER_NAME ": Failed to allocate char dev region\n");
        return ret;
    }

    cdev_init(&test_cdev, &test_fops);
    test_cdev.owner = THIS_MODULE;

    ret = cdev_add(&test_cdev, dev_num, 1);
    if (ret < 0) {
        pr_err(DRIVER_NAME ": Failed to add cdev\n");
        goto fail_cdev;
    }

    /* 创建设备类 */
    test_class = class_create(THIS_MODULE, DEVICE_NAME);
    if (IS_ERR(test_class)) {
        pr_err(DRIVER_NAME ": Failed to create class\n");
        ret = PTR_ERR(test_class);
        goto fail_class;
    }

    /* 创建设备节点 */
    if (IS_ERR(device_create(test_class, NULL, dev_num, NULL, DEVICE_NAME))) {
        pr_err(DRIVER_NAME ": Failed to create device\n");
        ret = -ENOMEM;
        goto fail_device;
    }

    /* 注册 platform 驱动 */
    ret = platform_driver_register(&test_platform_driver);
    if (ret) {
        pr_err(DRIVER_NAME ": Failed to register platform driver\n");
        goto fail_platform;
    }

    pr_info(DRIVER_NAME ": Module loaded successfully\n");
    pr_info(DRIVER_NAME ": Character device: /dev/%s (major %d)\n",
            DEVICE_NAME, MAJOR(dev_num));

    return 0;

fail_platform:
    device_destroy(test_class, dev_num);
fail_device:
    class_destroy(test_class);
fail_class:
    cdev_del(&test_cdev);
fail_cdev:
    unregister_chrdev_region(dev_num, 1);
    return ret;
}

/*
 * 模块退出
 */
static void __exit test_driver_exit(void)
{
    pr_info(DRIVER_NAME ": Unloading test driver module\n");

    /* 注销 platform 驱动 */
    platform_driver_unregister(&test_platform_driver);

    /* 删除设备节点 */
    device_destroy(test_class, dev_num);

    /* 删除设备类 */
    class_destroy(test_class);

    /* 注销字符设备 */
    cdev_del(&test_cdev);
    unregister_chrdev_region(dev_num, 1);

    pr_info(DRIVER_NAME ": Module unloaded successfully\n");
}

module_init(test_driver_init);
module_exit(test_driver_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Testing Project");
MODULE_DESCRIPTION("Simple test driver for load/unload testing");
MODULE_VERSION("1.0");
