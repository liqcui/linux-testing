# Makefile for lock_test

CC = gcc
CFLAGS = -O2 -Wall -Wextra -pthread
TARGET = lock_test
SRC = lock_test.c

.PHONY: all clean test perf

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)
	@echo "编译完成: $(TARGET)"
	@echo "运行: ./$(TARGET)"
	@echo "或使用: make test"

clean:
	rm -f $(TARGET) perf.data perf.data.old
	@echo "清理完成"

test: $(TARGET)
	@echo "========================================="
	@echo "运行锁性能测试"
	@echo "========================================="
	./$(TARGET)

perf-record: $(TARGET)
	@echo "========================================="
	@echo "使用 perf lock record 记录锁事件"
	@echo "========================================="
	perf lock record ./$(TARGET)

perf-report: perf.data
	@echo "========================================="
	@echo "使用 perf lock report 分析锁竞争"
	@echo "========================================="
	perf lock report

perf-contention: $(TARGET)
	@echo "========================================="
	@echo "使用 perf lock contention 实时分析"
	@echo "========================================="
	perf lock contention ./$(TARGET)

perf: perf-record perf-report

help:
	@echo "可用目标:"
	@echo "  make              - 编译程序"
	@echo "  make test         - 运行测试"
	@echo "  make perf-record  - 使用 perf lock record 记录"
	@echo "  make perf-report  - 使用 perf lock report 分析"
	@echo "  make perf         - 记录并分析 (record + report)"
	@echo "  make perf-contention - 实时锁竞争分析"
	@echo "  make clean        - 清理编译文件"
