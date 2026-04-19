CC = gcc
CFLAGS = -Wall -O2
TARGET = spidev_test

all: $(TARGET)

$(TARGET): spidev_test.c
	$(CC) $(CFLAGS) -o $(TARGET) spidev_test.c

clean:
	rm -f $(TARGET)

install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/

test: $(TARGET)
	@echo "运行基础测试..."
	sudo ./$(TARGET) -D /dev/spidev0.0 -v || echo "设备不存在，跳过测试"

.PHONY: all clean install test
