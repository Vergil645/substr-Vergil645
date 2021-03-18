#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cerrno>

size_t calc_prefix(size_t k, char elem, const char *temp, const size_t *p) {
    while (k > 0 && temp[k] != elem) {
        k = p[k - 1];
    }
    return temp[k] == elem ? k + 1 : k;
}

// Pred: 2 arguments: argv[1] -- filename
//                    argv[2] -- template string
// Post: print to stdout is argv[2] found in file argv[1] as a substring
int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Error: 2 arguments expected\n");
        return -1;
    }

    FILE *input = fopen(argv[1], "rb");
    if (errno) {
        fprintf(stderr, "Error: cannot open the file\n");
        return -1;
    }

    char *temp = argv[2];
    size_t temp_len = strlen(temp);

    // Knuth–Morris–Pratt algorithm
    auto *p = (size_t *) calloc(temp_len, sizeof(size_t));
    if (p == nullptr) {
        fprintf(stderr, "Error: cannot allocate a memory\n");
        return -1;
    }
    p[0] = 0;
    for (size_t i = 1; i < temp_len; i++) {
        p[i] = calc_prefix(p[i - 1], temp[i], temp, p);
    }

    const size_t buf_size = 1024;
    char buf[buf_size];
    size_t res_len = 0;
    bool flag = true;
    while (flag && !ferror(input) && !feof(input)) {
        size_t cnt = fread(buf, sizeof(char), buf_size, input);
        for (size_t i = 0; i < cnt; i++) {
            res_len = calc_prefix(res_len, buf[i], temp, p);
            if (res_len == temp_len) {
                flag = false;
                break;
            }
        }
    }

    int exit_code = 0;
    if (ferror(input)) {
        fprintf(stderr, "Error: read error\n");
        exit_code = -1;
    } else {
        fprintf(stdout, res_len == temp_len ? "Yes\n" : "No\n");
    }
    fclose(input);
    free(p);
    return exit_code;
}
