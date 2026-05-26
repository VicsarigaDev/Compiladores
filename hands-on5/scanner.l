%{
/*
 * scanner.l — Analizador léxico (Flex)
 * hands-on5: Práctica integradora — Extensión del compilador con Flex y Bison
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

int line_count = 1;
%}

/* Estado especial para consumir el resto de la línea de #include */
%x INCL

%%

"/"\"[^\n]*          { /* comentario de una línea — se ignora (mejora 5.1) */ }

\n                      { line_count++; }           /* contar líneas (mejora 5.2) */
[ \t\r]+                { /* ignorar espacios */ }

/* Directiva #include: consumir toda la línea (no la procesamos) */
"#include"              { BEGIN(INCL); }
<INCL>[ \t]+            { /* ignorar espacios tras #include */ }
<INCL>[^\n]*            { BEGIN(INITIAL); /* ignorar el archivo incluido */ }
<INCL>\n                { line_count++; BEGIN(INITIAL); }

/* Directiva #define */
"#define"               { return DEFINE; }

/* Palabras clave */
"func"                  { return FUNC; }
"int"                   { return INT_TYPE; }
"float"                 { return FLOAT_TYPE; }
"return"                { return RETURN; }
"if"                    { return IF; }

/* Literales numéricos */
[0-9]+\.[0-9]+          { yylval.fval = atof(yytext); return FLOAT_NUM; }
[0-9]+                  { yylval.ival = atoi(yytext); return INT_NUM; }

/* Identificadores */
[a-zA-Z_][a-zA-Z0-9_]* { yylval.sval = strdup(yytext); return ID; }

/* Operadores relacionales (deben ir ANTES que los simples) */
">="                    { return GE; }
"<="                    { return LE; }
"=="                    { return EQ; }
"!="                    { return NE; }
">"                     { return GT; }
"<"                     { return LT; }

/* Operadores aritméticos (mejora 5.3) */
"+"                     { return PLUS; }
"-"                     { return MINUS; }
"*"                     { return MULT; }
"/"                     { return DIV; }

/* Otros símbolos */
"="                     { return ASSIGN; }
";"                     { return SEMICOLON; }
","                     { return COMMA; }
"("                     { return LPAREN; }
")"                     { return RPAREN; }
"{"                     { return LBRACE; }
"}"                     { return RBRACE; }

.  {
    fprintf(stderr, "Error léxico: carácter '%s' en línea %d\n",
            yytext, line_count);
}

%%

int yywrap() { return 1; }
