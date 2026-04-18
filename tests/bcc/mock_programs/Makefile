# Makefile for BCC mock programs

CC = gcc
CFLAGS = -O2 -Wall -Wextra -pthread
LDFLAGS = -pthread -lm

PROGRAMS = file_opener disk_io tcp_client tcp_server cpu_burner blocker memory_leaker

.PHONY: all clean help

all: $(PROGRAMS)
	@echo "✓ 所有模拟程序编译完成"
	@echo ""
	@echo "可用程序:"
	@echo "  ./file_opener     - 文件打开模拟 (用于 opensnoop)"
	@echo "  ./disk_io         - 磁盘 I/O 模拟 (用于 biosnoop)"
	@echo "  ./tcp_client      - TCP 客户端 (用于 tcpconnect)"
	@echo "  ./tcp_server      - TCP 服务器 (用于 tcpaccept)"
	@echo "  ./cpu_burner      - CPU 密集型 (用于 profile, runqlat)"
	@echo "  ./blocker         - 阻塞操作 (用于 offcputime)"
	@echo "  ./memory_leaker   - 内存泄漏 (用于 memleak)"

file_opener: file_opener.c
	$(CC) $(CFLAGS) -o $@ $<

disk_io: disk_io.c
	$(CC) $(CFLAGS) -o $@ $<

tcp_client: tcp_client.c
	$(CC) $(CFLAGS) -o $@ $<

tcp_server: tcp_server.c
	$(CC) $(CFLAGS) -o $@ $<

cpu_burner: cpu_burner.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

blocker: blocker.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

memory_leaker: memory_leaker.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(PROGRAMS)
	@echo "✓ 清理完成"

help:
	@echo "BCC 模拟程序编译"
	@echo ""
	@echo "用法:"
	@echo "  make           - 编译所有程序"
	@echo "  make clean     - 清理编译文件"
	@echo "  make help      - 显示帮助"
	@echo ""
	@echo "单独编译:"
	@echo "  make file_opener"
	@echo "  make disk_io"
	@echo "  make tcp_client"
	@echo "  make tcp_server"
	@echo "  make cpu_burner"
	@echo "  make blocker"
	@echo "  make memory_leaker"
