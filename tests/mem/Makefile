# Makefile for mem_test

CC = gcc
CFLAGS = -O2 -Wall -Wextra -pthread
TARGET = mem_test
SRC = mem_test.c

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
	@echo "运行内存访问性能测试"
	@echo "========================================="
	./$(TARGET)

perf-mem-record: $(TARGET)
	@echo "========================================="
	@echo "使用 perf mem record 记录内存访问"
	@echo "========================================="
	perf mem record ./$(TARGET)

perf-mem-report: perf.data
	@echo "========================================="
	@echo "使用 perf mem report 分析内存访问"
	@echo "========================================="
	perf mem report

perf-cache: $(TARGET)
	@echo "========================================="
	@echo "使用 perf stat 分析缓存性能"
	@echo "========================================="
	@if perf list | grep -q "cache-references"; then \
		perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses ./$(TARGET); \
	else \
		perf stat -e cpu-clock,task-clock,page-faults ./$(TARGET); \
	fi

perf: perf-mem-record perf-mem-report

help:
	@echo "可用目标:"
	@echo "  make                - 编译程序"
	@echo "  make test           - 运行测试"
	@echo "  make perf-mem-record - 使用 perf mem record 记录"
	@echo "  make perf-mem-report - 使用 perf mem report 分析"
	@echo "  make perf-cache     - 使用 perf stat 分析缓存"
	@echo "  make perf           - 记录并分析 (record + report)"
	@echo "  make clean          - 清理编译文件"
