CC = gcc
CFLAGS = -Wall -Wextra -O2 -pthread
LDFLAGS = -pthread -lrt

TARGETS = rt_workload interrupt_generator

all: $(TARGETS)

rt_workload: rt_workload.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

interrupt_generator: interrupt_generator.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

test: all
	@echo "Testing rt_workload..."
	sudo ./rt_workload -p 80 -d 5
	@echo ""
	@echo "Testing interrupt_generator..."
	./interrupt_generator -i 1000 -d 5 -m timer

.PHONY: all clean test
