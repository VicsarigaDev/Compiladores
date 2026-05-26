%{
/*
 * scanner.l — Analizador léxico (Flex)
 * hands-on5: Extensión del compilador
 *
 * Mejoras léxicas implementadas:
 *   5.1 Reconocer comentarios de una línea (//)
 *   5.2 Contar líneas del código fuente
 *   5.3 Reconocer operadores aritméticos (+, -, *, /)
 */

#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int line_count = 1;   /* contador de líneas (mejora 5.2) */
%}

%%

"//"[^\n]*          { /* comentario de una línea — se ignora (mejora 5.1) */ }

\n                  { line_count++; }           /* contar líneas (mejora 5.2) */
[ \t\r]+            { /* espacios y tabulaciones — se ignoran */ }

"program"           { return PROGRAM; }
"begin"             { return BEGIN_KW; }
"end"               { return END_KW; }
"var"               { return VAR; }
"int"               { return INT_TYPE; }
"float"             { return FLOAT_TYPE; }
"if"                { return IF; }
"print"             { return PRINT; }
"read"              { return READ; }

[0-9]+\.[0-9]+      { yylval.fval = atof(yytext); return FLOAT_NUM; }
[0-9]+              { yylval.ival = atoi(yytext); return INT_NUM; }

[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }

">="                { return GE; }
"<="                { return LE; }
"=="                { return EQ; }
"!="                { return NE; }
">"                 { return GT; }
"<"                 { return LT; }

"+"                 { return PLUS; }    /* operadores aritméticos (mejora 5.3) */
"-"                 { return MINUS; }
"*"                 { return MULT; }
"/"                 { return DIV; }

"="                 { return ASSIGN; }
";"                 { return SEMICOLON; }
"("                 { return LPAREN; }
")"                 { return RPAREN; }

.  {
    fprintf(stderr, "Error léxico: carácter desconocido '%s' en línea %d\n",
            yytext, line_count);
}

%%

int yywrap() { return 1; }
