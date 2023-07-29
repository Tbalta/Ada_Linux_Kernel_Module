// main.c

#include <stdio.h>

extern void adainit (void);
extern void adafinal (void);
extern void hello_ada(void);

void hello_c(void)
{
    printf("Hello from C\n");
}

int main(void)
{
    adainit();
    hello_ada();
    adafinal();
    return 0;
}