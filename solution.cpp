#include <cstdio>

int main(int argc, char** argv)
{
    for (int i = 0; i < argc; ++i)
        fprintf(stderr, "%s\n", argv[i]);
}