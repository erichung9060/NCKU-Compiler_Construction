CC := gcc
CFLAGS := -Wall
SRC := scanner.l
TARGET := myscanner
VERBOSE := 0

all: ${TARGET}

${TARGET}: lex.yy.c
	@${CC} ${CFLAGS} -o $@ $<

lex.yy.c: ${SRC}
	@lex ${SRC}

judge: all
	@judge -v ${VERBOSE}

clean:
	@rm -f ${TARGET} lex.* *.out