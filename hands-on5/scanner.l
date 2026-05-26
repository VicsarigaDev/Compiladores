%{
/*
 * scanner.l - Analizador lexico (Flex)
 * hands-on5: Practica integradora - Extension del compilador con Flex y Bison
 *
 * Mejoras lexicas implementadas:
 *   5.1 Reconocer comentarios de una linea (//)
 *   5.2 Contar lineas del codigo fuente
 *   5.3 Reconocer operadores aritmeticos (+, -, *, /)
 */

#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int line_count = 1;
%}

%%

"//"[^\n]*              { /* comentario de una linea - se ignora (mejora 5.1) */ }

"#include"[^\n]*        { /* ignorar directivas #include */ }

"#define"               { return DEFINE; }

\n                      { line_count++; }
[ \t\r]+                { /* ignorar espacios */ }

"func"                  { return FUNC; }
"int"                   { return INT_TYPE; }
"float"                 { return FLOAT_TYPE; }
"return"                { return RETURN; }
"if"                    { return IF; }

[0-9]+\.[0-9]+          { yylval.fval = atof(yytext); return FLOAT_NUM; }
[0-9]+                  { yylval.ival = atoi(yytext); return INT_NUM; }

[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }

">="                    { return GE; }
"<="                    { return LE; }
"=="                    { return EQ; }
"!="                    { return NE; }
">"                     { return GT; }
"<"                     { return LT; }

"+"                     { return PLUS; }
"-"                     { return MINUS; }
"*"                     { return MULT; }
"/"                     { return DIV; }

"="                     { return ASSIGN; }
";"                     { return SEMICOLON; }
","                     { return COMMA; }
"("                     { return LPAREN; }
")"                     { return RPAREN; }
"{"                     { return LBRACE; }
"}"                     { return RBRACE; }

.  {
    fprintf(stderr, "Error lexico: caracter '%s' en linea %d\n",
            yytext, line_count);
}

%%

int yywrap() { return 1; }
