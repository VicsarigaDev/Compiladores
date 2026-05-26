# Makefile — hands-on5: Compilador con Flex y Bison

CC     = gcc
FLEX   = flex
BISON  = bison

TARGET = compiler

all: $(TARGET)

$(TARGET): parser.tab.c parser.tab.h lex.yy.c
	$(CC) -o $(TARGET) parser.tab.c lex.yy.c -lfl -lm

parser.tab.c parser.tab.h: parser.y
	$(BISON) -d -v parser.y

lex.yy.c: scanner.l parser.tab.h
	$(FLEX) scanner.l

test-correct: $(TARGET)
	./$(TARGET) correcto.c

test-incorrect: $(TARGET)
	./$(TARGET) errores.c

clean:
	rm -f parser.tab.c parser.tab.h parser.output lex.yy.c $(TARGET)

.PHONY: all test-correct test-incorrect clean
