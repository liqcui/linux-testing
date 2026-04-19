CC = gcc
CFLAGS = -Wall -O2 -pthread
TARGETS = cpu_hog mem_hog io_hog

all: $(TARGETS)

cpu_hog: cpu_hog.c
	$(CC) $(CFLAGS) -o cpu_hog cpu_hog.c

mem_hog: mem_hog.c
	$(CC) $(CFLAGS) -o mem_hog mem_hog.c

io_hog: io_hog.c
	$(CC) $(CFLAGS) -o io_hog io_hog.c

clean:
	rm -f $(TARGETS)

install: $(TARGETS)
	sudo cp $(TARGETS) /usr/local/bin/

test: $(TARGETS)
	@echo "测试CPU密集型程序（2线程，5秒）..."
	./cpu_hog 2 5
	@echo ""
	@echo "测试内存密集型程序（10MB）..."
	timeout 5 ./mem_hog 10 2 || true
	@echo ""
	@echo "测试I/O密集型程序（10MB）..."
	./io_hog 10 2

.PHONY: all clean install test
