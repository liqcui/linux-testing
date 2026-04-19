CC = gcc
CFLAGS = -Wall -O2
LDFLAGS = -lselinux
TARGET = test_selinux_prog

all: $(TARGET)

$(TARGET): test_selinux_prog.c
	$(CC) $(CFLAGS) -o $(TARGET) test_selinux_prog.c $(LDFLAGS)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/
	sudo restorecon -v /usr/local/bin/$(TARGET) 2>/dev/null || true

test: $(TARGET)
	@echo "运行SELinux测试程序..."
	./$(TARGET)

.PHONY: all clean install test
