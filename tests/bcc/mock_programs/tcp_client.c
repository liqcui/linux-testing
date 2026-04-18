/*
 * tcp_client.c - TCP 客户端模拟程序
 * 用于测试 tcpconnect
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>

int connect_to_host(const char *host, int port) {
    int sock;
    struct sockaddr_in server_addr;
    struct hostent *server;

    // 创建socket
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        return -1;
    }

    // 解析主机名
    server = gethostbyname(host);
    if (server == NULL) {
        close(sock);
        return -1;
    }

    // 设置服务器地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    memcpy(&server_addr.sin_addr.s_addr, server->h_addr, server->h_length);
    server_addr.sin_port = htons(port);

    // 连接
    if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        close(sock);
        return -1;
    }

    return sock;
}

int main(int argc, char *argv[]) {
    int iterations = 5;
    int delay_ms = 1000;
    int i, sock;

    if (argc > 1) {
        iterations = atoi(argv[1]);
    }
    if (argc > 2) {
        delay_ms = atoi(argv[2]);
    }

    printf("TCP Client Simulator - TCP 客户端模拟程序\n");
    printf("迭代次数: %d\n", iterations);
    printf("间隔: %d ms\n\n", delay_ms);

    // 测试的主机和端口列表
    struct {
        const char *host;
        int port;
        const char *desc;
    } targets[] = {
        {"www.google.com", 80, "Google HTTP"},
        {"www.github.com", 443, "GitHub HTTPS"},
        {"8.8.8.8", 53, "Google DNS"},
        {"localhost", 22, "本地 SSH"},
        {NULL, 0, NULL}
    };

    for (i = 0; i < iterations; i++) {
        int j;

        printf("[%d/%d] ", i + 1, iterations);

        for (j = 0; targets[j].host != NULL; j++) {
            sock = connect_to_host(targets[j].host, targets[j].port);

            if (sock >= 0) {
                printf("✓ %s:%d ", targets[j].host, targets[j].port);
                close(sock);
            } else {
                printf("✗ %s:%d ", targets[j].host, targets[j].port);
            }

            usleep(200000);  // 200ms between connections
        }

        printf("\n");
        usleep(delay_ms * 1000);
    }

    printf("\n完成！尝试建立 %d 个 TCP 连接\n", iterations * 4);
    return 0;
}
