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
		echo "使用硬件缓存事件..."; \
		perf stat -e cache-references,cache-misses,LLC-loads,LLC-load-misses ./$(TARGET); \
	else \
		echo "硬件缓存事件不可用，使用软件事件..."; \
		perf stat -e cpu-clock,task-clock,page-faults,minor-faults,major-faults ./$(TARGET); \
	fi

perf-vm: $(TARGET)
	@echo "========================================="
	@echo "虚拟机环境性能分析（不依赖硬件 PMU）"
	@echo "========================================="
	@echo "使用 perf stat 软件事件..."
	@perf stat -e cpu-clock,task-clock,page-faults,minor-faults,major-faults,context-switches ./$(TARGET)
	@echo ""
	@echo "对比不同访问模式的性能差异:"
	@echo ""
	@echo "顺序读:"
	@./$(TARGET) -t 1 -s 64 -n 5 | grep "顺序读"
	@echo ""
	@echo "随机读:"
	@./$(TARGET) -t 3 -s 64 -n 5 | grep "随机读"
	@echo ""
	@echo "伪共享:"
	@./$(TARGET) -t 6 -p 8 | grep "伪共享"
	@echo ""
	@echo "无伪共享:"
	@./$(TARGET) -t 7 -p 8 | grep "无伪共享"

perf: perf-mem-record perf-mem-report

help:
	@echo "可用目标:"
	@echo "  make                - 编译程序"
	@echo "  make test           - 运行测试"
	@echo "  make perf-mem-record - 使用 perf mem record 记录（需要硬件支持）"
	@echo "  make perf-mem-report - 使用 perf mem report 分析"
	@echo "  make perf-cache     - 使用 perf stat 分析缓存"
	@echo "  make perf-vm        - 虚拟机环境推荐使用（不需要硬件 PMU）"
	@echo "  make perf           - 记录并分析 (record + report)"
	@echo "  make clean          - 清理编译文件"
