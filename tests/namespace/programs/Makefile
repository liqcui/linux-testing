CC = gcc
CFLAGS = -Wall -O2
TARGET = namespace_test

all: $(TARGET)

$(TARGET): namespace_test.c
	$(CC) $(CFLAGS) -o $(TARGET) namespace_test.c

clean:
	rm -f $(TARGET)

install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/

test: $(TARGET)
	@echo "测试PID namespace..."
	sudo ./$(TARGET) -p -c "ps aux | head -10"
	@echo ""
	@echo "测试UTS namespace..."
	sudo ./$(TARGET) -u -c "hostname"

.PHONY: all clean install test
