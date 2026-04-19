CC = gcc
CFLAGS = -Wall -Wextra -O2 -pthread
LDFLAGS = -pthread -lrt -lm

TARGETS = rt_workload interrupt_generator cpu_intensive_workload realtime_task

all: $(TARGETS)

rt_workload: rt_workload.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

interrupt_generator: interrupt_generator.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

cpu_intensive_workload: cpu_intensive_workload.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

realtime_task: realtime_task.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

test: all
	@echo "Testing rt_workload..."
	sudo ./rt_workload -p 80 -d 5
	@echo ""
	@echo "Testing interrupt_generator..."
	./interrupt_generator -i 1000 -d 5 -m timer
	@echo ""
	@echo "Testing cpu_intensive_workload..."
	./cpu_intensive_workload -d 5 -w mixed -i 5
	@echo ""
	@echo "Testing realtime_task..."
	sudo ./realtime_task -p 10000 -r 2000 -d 5 -s fifo -P 80

.PHONY: all clean test
