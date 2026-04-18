# Makefile for syscalls_test

CC = gcc
CFLAGS = -O2 -Wall -Wextra
TARGET = syscalls_test
SRC = syscalls_test.c

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)
	@echo "编译完成: $(TARGET)"
	@echo "运行: ./$(TARGET)"
	@echo "或使用: make test"

clean:
	rm -f $(TARGET)
	@echo "清理完成"

test: $(TARGET)
	@echo "========================================="
	@echo "运行系统调用性能测试"
	@echo "========================================="
	./$(TARGET)

perf: $(TARGET)
	@echo "========================================="
	@echo "使用 perf 分析系统调用性能"
	@echo "========================================="
	@if perf list hardware 2>/dev/null | grep -q cycles; then \
		echo "使用硬件事件..."; \
		perf stat -e cycles -e instructions -e cache-misses -e context-switches ./$(TARGET); \
	else \
		echo "硬件事件不可用，使用软件事件..."; \
		perf stat -e cpu-clock -e task-clock -e page-faults -e context-switches -e cpu-migrations ./$(TARGET); \
	fi

strace: $(TARGET)
	@echo "========================================="
	@echo "使用 strace 跟踪系统调用"
	@echo "========================================="
	strace -c ./$(TARGET)

help:
	@echo "可用目标:"
	@echo "  make         - 编译程序"
	@echo "  make test    - 运行测试"
	@echo "  make perf    - 使用 perf 分析"
	@echo "  make strace  - 使用 strace 跟踪"
	@echo "  make clean   - 清理编译文件"
