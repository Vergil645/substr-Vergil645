#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>

void end_of_main(uint32_t res_len, uint32_t temp_len, FILE *input, uint32_t *p, char *buf, int code) {
    if (res_len == temp_len) {
        printf("Yes\n");
    } else {
        printf(code != 0 ? "Error: read error\n" : "No\n");
    }
    fclose(input);
    free(p);
    free(buf);
    exit(code);
}

void error(char *message) {
    fprintf(stderr, "%s\n", message);
    exit(-1);
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        error((char *) "Error: 2 arguments expected");
    }

    FILE *input = fopen(argv[1], "rb");
    if (input == nullptr) {
        error((char *) "Error: cannot open the file");
    }

    size_t temp_len = strlen(argv[2]);

    // Knuth–Morris–Pratt algorithm
    auto *p = (uint32_t *) calloc(temp_len, 4);
    p[0] = 0;
    for (size_t i = 1; i < temp_len; i++) {
        uint32_t k = p[i - 1];
        while (k > 0 && argv[2][k] != argv[2][i]) {
            k = p[k - 1];
        }
        if (argv[2][k] == argv[2][i]) {
            k++;
        }
        p[i] = k;
    }

    size_t buf_size = 1024;
    char *buf = (char *) calloc(buf_size, 1);
    uint32_t res_len = 0;

    while (true) {
        size_t cnt = fread(buf, 1, buf_size, input);
        for (size_t i = 0; i < cnt; i++) {
            uint32_t k = res_len;
            while (k > 0 && argv[2][k] != buf[i]) {
                k = p[k - 1];
            }
            if (argv[2][k] == buf[i]) {
                k++;
            }
            res_len = k;
            if (res_len == temp_len) {
                end_of_main(res_len, temp_len, input, p, buf, 0);
            }
        }
        if (ferror(input) != 0) {
            end_of_main(res_len, temp_len, input, p, buf, -1);
        }
        if (feof(input) != 0) {
            break;
        }
    }
    end_of_main(res_len, temp_len, input, p, buf, 0);
    return 0;
}
