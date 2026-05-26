%{
/*
 * parser.y — Analizador sintáctico y semántico (Bison)
 * hands-on5: Práctica integradora — Extensión del compilador con Flex y Bison
 *
 * Mejoras sintácticas (§6):
 *   6.1 Expresiones aritméticas simples
 *   6.2 Sentencia if simple con bloque {}
 *   6.3 Mejores mensajes de error con número de línea y recuperación
 *
 * Mejoras semánticas (§7):
 *   7.1 Imprimir tabla de símbolos al final
 *   7.2 Detectar variables declaradas pero no usadas
 *   7.3 Verificar variables usadas en condiciones if
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int   line_count;
extern int   yylex(void);
extern FILE *yyin;

void yyerror(const char *msg);

/* ============================================================
 * Tabla de macros (#define)
 * ============================================================ */
typedef struct { char name[64]; int value; } Macro;
static Macro macros[128];
static int   macro_n = 0;

static void macro_add(const char *name, int value) {
    int i;
    for (i = 0; i < macro_n; i++) {
        if (strcmp(macros[i].name, name) == 0) {
            fprintf(stderr, "Error semántico: macro '%s' ya definida\n", name);
            return;
        }
    }
    strncpy(macros[macro_n].name, name, 63);
    macros[macro_n].value = value;
    macro_n++;
}

/* ============================================================
 * Tabla de funciones
 * ============================================================ */
typedef struct { char name[64]; int param_count; } FuncEntry;
static FuncEntry funcs[64];
static int       func_n = 0;

static int func_lookup(const char *name) {
    int i;
    for (i = 0; i < func_n; i++)
        if (strcmp(funcs[i].name, name) == 0) return i;
    return -1;
}

static void func_add(const char *name, int param_count) {
    strncpy(funcs[func_n].name, name, 63);
    funcs[func_n].param_count = param_count;
    func_n++;
}

/* ============================================================
 * Tabla de símbolos (variables con ámbitos)
 * ============================================================ */
typedef struct {
    char name[64];
    char type[16];
    int  scope;
    int  used;
    int  is_param;   /* los parámetros no generan advertencia de no-uso */
} Symbol;

static Symbol syms[512];
static int    sym_n     = 0;
static int    cur_scope = 0;

/* Busca en todos los ámbitos visibles (del más interno al más externo) */
static int sym_lookup(const char *name) {
    int i;
    for (i = sym_n - 1; i >= 0; i--)
        if (strcmp(syms[i].name, name) == 0) return i;
    return -1;
}

/* Busca SOLO en el ámbito actual (para detectar redeclaraciones) */
static int sym_in_scope(const char *name, int scope) {
    int i;
    for (i = 0; i < sym_n; i++)
        if (syms[i].scope == scope && strcmp(syms[i].name, name) == 0) return i;
    return -1;
}

static void sym_add(const char *name, const char *type, int is_param) {
    if (sym_in_scope(name, cur_scope) >= 0) {
        fprintf(stderr, "Error semántico: redeclaración de variable '%s'\n", name);
        return;
    }
    strncpy(syms[sym_n].name,  name, 63);
    strncpy(syms[sym_n].type,  type, 15);
    syms[sym_n].scope    = cur_scope;
    syms[sym_n].used     = 0;
    syms[sym_n].is_param = is_param;
    sym_n++;
}

static void sym_mark_used(const char *name) {
    int idx = sym_lookup(name);
    if (idx >= 0) syms[idx].used = 1;
}

/* 7.2 — Salir de ámbito: reportar no-usadas y eliminar */
static void scope_exit(void) {
    int i, new_n = 0;
    /* Advertir variables no usadas (no aplica a parámetros) */
    for (i = 0; i < sym_n; i++) {
        if (syms[i].scope == cur_scope && !syms[i].used && !syms[i].is_param)
            fprintf(stderr,
                "Advertencia: variable '%s' declarada pero no usada\n",
                syms[i].name);
    }
    /* Eliminar todos los símbolos del ámbito que se cierra */
    for (i = 0; i < sym_n; i++)
        if (syms[i].scope != cur_scope)
            syms[new_n++] = syms[i];
    sym_n = new_n;
    cur_scope--;
}

/* ============================================================
 * Estado global para análisis semántico
 * ============================================================ */
static int arg_count    = 0;  /* args contados en la llamada actual */
static int in_condition = 0;  /* 7.3: ¿parsing dentro de condición if? */

/* 7.3 — Verifica declaración de variable; emite el mensaje adecuado */
static void check_var(const char *name) {
    if (sym_lookup(name) < 0) {
        if (in_condition)
            fprintf(stderr,
                "Error semántico: variable condición '%s' no declarada\n", name);
        else
            fprintf(stderr,
                "Error semántico: variable '%s' no declarada\n", name);
    } else {
        sym_mark_used(name);
    }
}

/* 7.1 — Imprimir tablas al finalizar */
static void print_tables(void) {
    int i;
    printf("\n=== Tabla de Macros (#define) ===\n");
    if (macro_n == 0) printf("  (ninguna)\n");
    else {
        printf("  %-20s %s\n", "Nombre", "Valor");
        for (i = 0; i < macro_n; i++)
            printf("  %-20s %d\n", macros[i].name, macros[i].value);
    }
    printf("\n=== Tabla de Funciones ===\n");
    if (func_n == 0) printf("  (ninguna)\n");
    else {
        printf("  %-20s %s\n", "Nombre", "Parámetros");
        for (i = 0; i < func_n; i++)
            printf("  %-20s %d\n", funcs[i].name, funcs[i].param_count);
    }
    printf("\n=== Tabla de Símbolos Globales ===\n");
    if (sym_n == 0) printf("  (ninguna)\n");
    else {
        printf("  %-20s %s\n", "Nombre", "Tipo");
        for (i = 0; i < sym_n; i++)
            printf("  %-20s %s\n", syms[i].name, syms[i].type);
    }
    printf("\n");
}

/* Parámetros acumulados de la función en declaración */
static char func_params[32][64];
static int  func_param_n = 0;
%}

/* ---- Tipo semántico ---- */
%union {
    int   ival;
    float fval;
    char *sval;
}

%token <sval> ID
%token <ival> INT_NUM
%token <fval> FLOAT_NUM

%token DEFINE FUNC RETURN IF
%token INT_TYPE FLOAT_TYPE
%token PLUS MINUS MULT DIV
%token GT LT GE LE EQ NE
%token ASSIGN SEMICOLON COMMA
%token LPAREN RPAREN LBRACE RBRACE

/* Precedencia y asociatividad (6.1) — de menor a mayor */
%left GT LT GE LE EQ NE
%left PLUS MINUS
%left MULT DIV

%start program

%%

program
    : top_decls {
        printf("Análisis completado. Líneas procesadas: %d\n", line_count);
        print_tables();
      }
    ;

top_decls
    : top_decls top_decl
    | /* vacío */
    ;

top_decl
    /* Macro: #define NOMBRE VALOR */
    : DEFINE ID INT_NUM {
        macro_add($2, $3);
        free($2);
      }

    /* Variable global entera */
    | INT_TYPE ID SEMICOLON {
        sym_add($2, "int", 0);
        free($2);
      }

    /* Variable global flotante */
    | FLOAT_TYPE ID SEMICOLON {
        sym_add($2, "float", 0);
        free($2);
      }

    /* Declaración de función (6.2) */
    | func_header LBRACE stmts RBRACE {
        scope_exit();
      }
    ;

/*
 * func_header: procesa el encabezado de la función,
 * registra en la tabla de funciones y entra al ámbito.
 */
func_header
    : FUNC ID LPAREN { func_param_n = 0; } param_list RPAREN {
        if (func_lookup($2) >= 0) {
            /* 7.2 — redeclaración de función */
            fprintf(stderr,
                "Error semántico: variable '%s' ya declarada\n", $2);
        } else {
            func_add($2, func_param_n);
        }
        /* Entrar al ámbito de la función */
        cur_scope++;
        {
            int i;
            for (i = 0; i < func_param_n; i++)
                sym_add(func_params[i], "param", 1);
        }
        free($2);
      }
    ;

param_list
    : params
    | /* vacío */
    ;

params
    : ID {
        strncpy(func_params[func_param_n++], $1, 63);
        free($1);
      }
    | params COMMA ID {
        strncpy(func_params[func_param_n++], $3, 63);
        free($3);
      }
    ;

stmts
    : stmts stmt
    | /* vacío */
    ;

stmt
    /* Declaración de variable local entera */
    : INT_TYPE ID SEMICOLON {
        sym_add($2, "int", 0);
        free($2);
      }

    /* Declaración de variable local flotante */
    | FLOAT_TYPE ID SEMICOLON {
        sym_add($2, "float", 0);
        free($2);
      }

    /* Asignación */
    | ID ASSIGN expr SEMICOLON {
        if (sym_lookup($1) < 0)
            fprintf(stderr,
                "Error semántico: variable '%s' no declarada\n", $1);
        else
            sym_mark_used($1);
        free($1);
      }

    /* Llamada a función como sentencia */
    | ID LPAREN { arg_count = 0; } arg_list RPAREN SEMICOLON {
        int idx = func_lookup($1);
        if (idx < 0) {
            fprintf(stderr,
                "Error semántico: función '%s' no declarada\n", $1);
        } else if (funcs[idx].param_count != arg_count) {
            fprintf(stderr,
                "Error semántico: función '%s' espera %d argumento(s), pero recibió %d\n",
                $1, funcs[idx].param_count, arg_count);
        }
        free($1);
      }

    /* Sentencia if simple con bloque (6.2) */
    | IF LPAREN { in_condition = 1; } expr { in_condition = 0; } RPAREN
      LBRACE { cur_scope++; } stmts RBRACE { scope_exit(); }

    /* Sentencia return */
    | RETURN expr SEMICOLON

    /* Recuperación de error sintáctico (6.3) */
    | error SEMICOLON {
        fprintf(stderr,
            "Error sintáctico (línea %d): sentencia inválida\n", line_count);
        yyerrok;
      }
    ;

arg_list
    : args
    | /* vacío */
    ;

args
    : expr               { arg_count = 1; }
    | args COMMA expr    { arg_count++; }
    ;

/* 6.1 — Expresiones aritméticas y relacionales con precedencia */
expr
    : expr PLUS  expr
    | expr MINUS expr
    | expr MULT  expr
    | expr DIV   expr
    | expr GT    expr
    | expr LT    expr
    | expr GE    expr
    | expr LE    expr
    | expr EQ    expr
    | expr NE    expr
    | LPAREN expr RPAREN
    | INT_NUM
    | FLOAT_NUM
    | ID {
        check_var($1);   /* 7.3 — verifica que la variable esté declarada */
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
        printf("Ingresa el código fuente (Ctrl+D para terminar):\n");
        yyin = stdin;
    }

    yyparse();

    if (argc > 1 && yyin)
        fclose(yyin);

    return 0;
}
