#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/md5.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netdb.h>

#define TABLE_SIZE (1 << 24)
#define PREFIX_LEN 8
#define SERVER "140.112.91.4"
#define PORT 1234

typedef struct {
    char prefix[PREFIX_LEN + 1];
    int value;
} Entry;

Entry *table = NULL;

// Compute the 8-char prefix of the MD5 hash of the string representation of i
void compute_prefix(int i, char *out_prefix) {
    unsigned char md5[MD5_DIGEST_LENGTH];
    char istr[16];
    snprintf(istr, sizeof(istr), "%d", i);
    MD5((unsigned char*)istr, strlen(istr), md5);
    for (int j = 0; j < 4; ++j) {
        sprintf(out_prefix + 2*j, "%02x", md5[j]);
    }
    out_prefix[PREFIX_LEN] = '\0';
}

// Compare function for qsort and bsearch
int cmp_prefix(const void *a, const void *b) {
    return strncmp(((Entry*)a)->prefix, ((Entry*)b)->prefix, PREFIX_LEN);
}

// Precompute the table and sort it
void precompute() {
    table = malloc(TABLE_SIZE * sizeof(Entry));
    if (!table) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(1);
    }
    for (int i = 0; i < TABLE_SIZE; ++i) {
        compute_prefix(i, table[i].prefix);
        table[i].value = i;
        if (i % (TABLE_SIZE / 10) == 0) {
            printf("Precomputed %d entries...\n", i);
        }
    }
    printf("Sorting table...\n");
    qsort(table, TABLE_SIZE, sizeof(Entry), cmp_prefix);
    printf("Table sorted.\n");
}

// Lookup the integer for a given prefix using binary search
int lookup(const char *prefix) {
    Entry key;
    strncpy(key.prefix, prefix, PREFIX_LEN);
    key.prefix[PREFIX_LEN] = '\0';
    Entry *res = bsearch(&key, table, TABLE_SIZE, sizeof(Entry), cmp_prefix);
    return res ? res->value : -1;
}

// Read a line from the socket
ssize_t read_line(int sockfd, char *buf, size_t maxlen) {
    size_t n = 0;
    char c;
    while (n < maxlen - 1) {
        ssize_t r = read(sockfd, &c, 1);
        if (r <= 0) break;
        buf[n++] = c;
        if (c == '\n') break;
    }
    buf[n] = '\0';
    return n;
}

int main() {
    precompute();

    // Connect to server
    struct sockaddr_in serv_addr;
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) { perror("socket"); exit(1); }
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);
    inet_pton(AF_INET, SERVER, &serv_addr.sin_addr);
    if (connect(sockfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("connect");
        exit(1);
    }

    char buf[4096];
    // Wait for menu prompt "Your choice:"
	printf("Waiting for menu...\n");
	char menu_prompt[] = "Your choice:";
	size_t prompt_len = strlen(menu_prompt);
	size_t matched = 0;
	char c;
	while (1) {
		ssize_t r = read(sockfd, &c, 1);
		if (r <= 0) {
			fprintf(stderr, "Connection closed or error while waiting for menu.\n");
			exit(1);
		}
		// Print received char for debug
		putchar(c);
		fflush(stdout);
		if (c == menu_prompt[matched]) {
			matched++;
			if (matched == prompt_len) break; // Found the prompt!
		} else {
			matched = (c == menu_prompt[0]) ? 1 : 0;
		}
	}
    // Send menu choice 4
    write(sockfd, "4\n", 2);
	printf("Sent menu choice 4\n");
    for (int round = 0; round < 10; ++round) {
		// Search for the PoW prompt in a rolling buffer
		char pow_prompt[] = "md5(i)[0:8] == \"";
		size_t pow_prompt_len = strlen(pow_prompt);
		char rolling_buf[64] = {0};
		size_t rolling_len = 0;
		char c;
		while (1) {
			ssize_t r = read(sockfd, &c, 1);
			if (r <= 0) {
				fprintf(stderr, "Connection closed or error while waiting for PoW prompt.\n");
				exit(1);
			}
			// Shift buffer and append new char
			if (rolling_len < sizeof(rolling_buf) - 1) {
				rolling_buf[rolling_len++] = c;
			} else {
				memmove(rolling_buf, rolling_buf + 1, sizeof(rolling_buf) - 2);
				rolling_buf[sizeof(rolling_buf) - 2] = c;
			}
			rolling_buf[rolling_len] = '\0';

			// Check for prompt
			char *p = strstr(rolling_buf, pow_prompt);
			if (p) {
				// Extract the prefix (8 hex chars after the prompt)
				char prefix[PREFIX_LEN + 1];
				size_t offset = p - rolling_buf + pow_prompt_len;
				// If not enough chars yet, keep reading
				while (rolling_len < offset + PREFIX_LEN) {
					ssize_t r2 = read(sockfd, &c, 1);
					if (r2 <= 0) {
						fprintf(stderr, "Connection closed while reading prefix.\n");
						exit(1);
					}
					if (rolling_len < sizeof(rolling_buf) - 1) {
						rolling_buf[rolling_len++] = c;
					}
					rolling_buf[rolling_len] = '\0';
				}
				strncpy(prefix, rolling_buf + offset, PREFIX_LEN);
				prefix[PREFIX_LEN] = '\0';
				// printf("Found prefix: %s\n", prefix);
				int ans = lookup(prefix);
				if (ans == -1) {
					fprintf(stderr, "Prefix not found: %s\n", prefix);
					exit(1);
				}
				char ansbuf[32];
				snprintf(ansbuf, sizeof(ansbuf), "%d\n", ans);
				// printf("Sending answer: %s", ansbuf);
				write(sockfd, ansbuf, strlen(ansbuf));
				break;
			}
		}
	}
    // Print the rest (flag)
    while (read_line(sockfd, buf, sizeof(buf)) > 0) {
        printf("%s", buf);
    }

    free(table);
    close(sockfd);
    return 0;
}