# Makefile for bpftrace mock programs

CC = gcc
CFLAGS = -O2 -Wall -Wextra -pthread
LDFLAGS = -pthread

PROGRAMS = syscall_simulator \
           latency_simulator \
           memory_allocator \
           process_spawner \
           io_generator

all: $(PROGRAMS)

syscall_simulator: syscall_simulator.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

latency_simulator: latency_simulator.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

memory_allocator: memory_allocator.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

process_spawner: process_spawner.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

io_generator: io_generator.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(PROGRAMS)

.PHONY: all clean
