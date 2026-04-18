/*
 * tcp_server.c - TCP 服务器模拟程序
 * 用于测试 tcpaccept
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <errno.h>

static volatile int keep_running = 1;

void signal_handler(int sig) {
    (void)sig;
    keep_running = 0;
}

int main(int argc, char *argv[]) {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len;
    int port = 8888;
    int max_connections = 10;
    int connection_count = 0;

    if (argc > 1) {
        port = atoi(argv[1]);
    }
    if (argc > 2) {
        max_connections = atoi(argv[2]);
    }

    printf("TCP Server Simulator - TCP 服务器模拟程序\n");
    printf("监听端口: %d\n", port);
    printf("最大连接数: %d\n\n", max_connections);

    // 设置信号处理
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // 创建 socket
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        return 1;
    }

    // 允许地址重用
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    // 绑定地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("bind");
        close(server_fd);
        return 1;
    }

    // 监听
    if (listen(server_fd, 5) < 0) {
        perror("listen");
        close(server_fd);
        return 1;
    }

    printf("服务器启动成功，等待连接...\n");
    printf("使用另一个终端测试: nc localhost %d\n", port);
    printf("按 Ctrl+C 停止服务器\n\n");

    // 接受连接
    while (keep_running && connection_count < max_connections) {
        client_len = sizeof(client_addr);

        // 设置超时，以便能够响应信号
        struct timeval timeout;
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        setsockopt(server_fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

        client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);

        if (client_fd < 0) {
            if (errno == EWOULDBLOCK || errno == EAGAIN) {
                continue;  // 超时，继续循环
            }
            if (!keep_running) break;
            perror("accept");
            continue;
        }

        connection_count++;

        printf("[%d/%d] ✓ 接受连接: %s:%d (fd=%d)\n",
               connection_count,
               max_connections,
               inet_ntoa(client_addr.sin_addr),
               ntohs(client_addr.sin_port),
               client_fd);

        // 发送欢迎消息
        const char *msg = "Welcome to TCP Test Server!\n";
        write(client_fd, msg, strlen(msg));

        // 立即关闭连接
        close(client_fd);
    }

    close(server_fd);

    printf("\n完成！共接受 %d 个连接\n", connection_count);
    return 0;
}
