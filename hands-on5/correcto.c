#include <stdio.h>
#define MAX 100

int global;

func suma(a,b) {
    int resultado;
    resultado = a + b;
    return resultado;
}

func main() {
    int x;
    int y;

    x = y;
    suma(x,y);

    if (x) {
        int z;
        z = x;
    }

    return x;
}
