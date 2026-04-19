CC = gcc
CFLAGS = -Wall -O2
TARGET = gpio_test

all: $(TARGET)

$(TARGET): gpio_test.c
	$(CC) $(CFLAGS) -o $(TARGET) gpio_test.c

clean:
	rm -f $(TARGET)

install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/

test: $(TARGET)
	@echo "运行GPIO测试（需要root权限）..."
	@echo "请手动运行: sudo ./$(TARGET) -g <GPIO编号> -o export"

.PHONY: all clean install test
