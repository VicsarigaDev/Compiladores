%{
/*
 * parser.y — Analizador sintáctico y semántico (Bison)
 * hands-on5: Extensión del compilador
 *
 * Mejoras sintácticas implementadas:
 *   6.1 Expresiones aritméticas simples
 *   6.2 Sentencia if simple
 *   6.3 Mejores mensajes de error sintáctico
 *
 * Mejoras semánticas implementadas:
 *   7.1 Imprimir tabla de símbolos final
 *   7.2 Detectar variables declaradas pero no usadas
 *   7.3 Verificar variables usadas en condiciones if
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int line_count;
extern int yylex();
extern FILE *yyin;

void yyerror(const char *msg);

/* -------- Tabla de símbolos -------- */
#define MAX_SYMBOLS 256

typedef struct {
    char name[64];
    char type[16];
    int  used;      /* 0 = no usada, 1 = usada */
} Symbol;

static Symbol sym_table[MAX_SYMBOLS];
static int    sym_count = 0;

static void sym_add(const char *name, const char *type) {
    int i;
    for (i = 0; i < sym_count; i++) {
        if (strcmp(sym_table[i].name, name) == 0) {
            fprintf(stderr,
                "Error semántico (línea %d): variable '%s' ya fue declarada\n",
                line_count, name);
            return;
        }
    }
    if (sym_count >= MAX_SYMBOLS) {
        fprintf(stderr, "Error interno: tabla de símbolos llena\n");
        return;
    }
    strncpy(sym_table[sym_count].name, name, 63);
    strncpy(sym_table[sym_count].type, type, 15);
    sym_table[sym_count].used = 0;
    sym_count++;
}

static int sym_lookup(const char *name) {
    int i;
    for (i = 0; i < sym_count; i++)
        if (strcmp(sym_table[i].name, name) == 0) return i;
    return -1;
}

static void sym_mark_used(const char *name) {
    int idx = sym_lookup(name);
    if (idx >= 0) sym_table[idx].used = 1;
}

/* 7.1 — Imprimir tabla de símbolos */
static void sym_print(void) {
    int i;
    printf("\n=== Tabla de Símbolos ===\n");
    printf("%-20s %-10s %-8s\n", "Nombre", "Tipo", "Usada");
    printf("%-20s %-10s %-8s\n", "------", "----", "-----");
    for (i = 0; i < sym_count; i++) {
        printf("%-20s %-10s %-8s\n",
               sym_table[i].name,
               sym_table[i].type,
               sym_table[i].used ? "Si" : "No");
    }
    printf("=========================\n");
}

/* 7.2 — Detectar variables declaradas pero no usadas */
static void sym_check_unused(void) {
    int i, found = 0;
    for (i = 0; i < sym_count; i++) {
        if (!sym_table[i].used) {
            if (!found) {
                printf("\n=== Advertencia: variables declaradas pero no usadas ===\n");
                found = 1;
            }
            printf("  - %s (%s)\n", sym_table[i].name, sym_table[i].type);
        }
    }
    if (found)
        printf("======================================================\n");
}
%}

/* ---- Tipos de valor semántico ---- */
%union {
    int   ival;
    float fval;
    char *sval;
}

/* ---- Tokens con valor ---- */
%token <sval> ID
%token <ival> INT_NUM
%token <fval> FLOAT_NUM

/* ---- Tokens simples (palabras clave y operadores) ---- */
%token PROGRAM BEGIN_KW END_KW
%token VAR INT_TYPE FLOAT_TYPE
%token IF PRINT READ
%token PLUS MINUS MULT DIV
%token GT LT GE LE EQ NE
%token ASSIGN SEMICOLON LPAREN RPAREN

/* ---- Precedencia y asociatividad (6.1) ---- */
%left PLUS MINUS
%left MULT DIV

%start program

%%

program
    : PROGRAM ID BEGIN_KW stmts END_KW {
        printf("\nAnálisis completado exitosamente.\n");
        printf("Total de líneas procesadas: %d\n", line_count);
        sym_print();
        sym_check_unused();
        free($2);
      }
    | error {
        fprintf(stderr, "Error sintáctico: estructura del programa inválida\n");
      }
    ;

stmts
    : stmts stmt
    | /* vacío */
    ;

stmt
    /* Declaración de variable entera */
    : VAR INT_TYPE ID SEMICOLON {
        sym_add($3, "int");
        free($3);
      }

    /* Declaración de variable flotante */
    | VAR FLOAT_TYPE ID SEMICOLON {
        sym_add($3, "float");
        free($3);
      }

    /* Asignación con expresión aritmética (6.1) */
    | ID ASSIGN expr SEMICOLON {
        if (sym_lookup($1) < 0)
            fprintf(stderr,
                "Error semántico (línea %d): variable '%s' no fue declarada\n",
                line_count, $1);
        else
            sym_mark_used($1);
        free($1);
      }

    /* Sentencia if simple (6.2) */
    | IF LPAREN condition RPAREN stmt {
        /* la verificación de variables se realiza en las reglas de condition/expr */
      }

    /* Sentencia print */
    | PRINT LPAREN expr RPAREN SEMICOLON

    /* Sentencia read */
    | READ LPAREN ID RPAREN SEMICOLON {
        if (sym_lookup($3) < 0)
            fprintf(stderr,
                "Error semántico (línea %d): variable '%s' no fue declarada\n",
                line_count, $3);
        else
            sym_mark_used($3);
        free($3);
      }

    /* Recuperación de error (6.3) */
    | error SEMICOLON {
        fprintf(stderr,
            "Error sintáctico (línea %d): sentencia inválida — se omite hasta ';'\n",
            line_count);
        yyerrok;
      }
    ;

/* 7.3 — Condición del if: verifica que las variables estén declaradas */
condition
    : expr GT   expr
    | expr LT   expr
    | expr GE   expr
    | expr LE   expr
    | expr EQ   expr
    | expr NE   expr
    ;

/* Expresiones aritméticas (6.1) — gramática no ambigua */
expr
    : expr PLUS  term
    | expr MINUS term
    | term
    ;

term
    : term MULT  factor
    | term DIV   factor
    | factor
    ;

factor
    : INT_NUM
    | FLOAT_NUM
    | LPAREN expr RPAREN
    | ID {
        /* 7.3 — verifica que la variable usada en cualquier expresión (incluyendo if) esté declarada */
        if (sym_lookup($1) < 0)
            fprintf(stderr,
                "Error semántico (línea %d): variable '%s' no fue declarada\n",
                line_count, $1);
        else
            sym_mark_used($1);
        free($1);
      }
    ;

%%

void yyerror(const char *msg) {
    fprintf(stderr, "Error sintáctico (línea %d): %s\n", line_count, msg);
}

int main(int argc, char *argv[]) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Error: no se puede abrir el archivo '%s'\n", argv[1]);
            return 1;
        }
    } else {
        printf("Ingresa el código fuente (Ctrl+D / Ctrl+Z para terminar):\n");
        yyin = stdin;
    }

    yyparse();

    if (argc > 1 && yyin)
        fclose(yyin);

    return 0;
}
