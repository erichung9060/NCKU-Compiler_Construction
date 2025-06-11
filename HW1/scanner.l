/* Definition section */
%{
   #include <stdio.h>
   #include <stdlib.h>
   #include <string.h>

   #define YY_NO_UNPUT
   #define YY_NO_INPUT
   /* print_token prints tokens; for multi-line lexemes, prints lines, with token on last line */
   static void print_token_real(const char *token) {
       char *start = yytext;
       char *newline_pos;
       if (strcmp(token, "NEWLINE") == 0) {
           printf("%-8s \t %s\n", "", token);
           return;
       }
       while ((newline_pos = strchr(start, '\n')) != NULL) {
           *newline_pos = '\0';
           printf("%s\n", start);
           start = newline_pos + 1;
       }
       printf("%-8s \t %s\n", start, token);
   }

   #define print_token(token) print_token_real(token)

   int line_num = 0;
   int comment_num = 0;
   int last_comment_line = -1;
%}


/* Define regular expression label */
letter [a-zA-Z_]
digit [0-9]


/* Rules section */
%x COMMENT STRING

%%

<INITIAL>"/\*" {
    if (last_comment_line != line_num) {
        comment_num++;
        last_comment_line = line_num;
    }
    BEGIN(COMMENT);
    yymore();
}

<COMMENT>"\*/" {
    yymore();
    /* print multi-line comment lexeme and token */
    printf("%s", yytext);
    printf("       \t %s\n", "MUTI_LINE_COMMENT");
    BEGIN(INITIAL);
}

<COMMENT>\n {
    yymore();
    line_num++;
    if (last_comment_line != line_num) {
        comment_num++;
        last_comment_line = line_num;
    }
}

<COMMENT>. {
    yymore();
}

"//".* {
    print_token("COMMENT");
    if (last_comment_line != line_num) {
        comment_num++;
        last_comment_line = line_num;
    }
}

"\"" {
    print_token("QUOTA");
    BEGIN(STRING);
}

<STRING>[^\"\n]+ {
    print_token("STRING_LIT");
}

<STRING>"\"" {
    print_token("QUOTA");
    BEGIN(INITIAL);
}

{digit}+"."{digit}+ {
    print_token("FLOAT_LIT");
}

{digit}+ {
    print_token("INT_LIT");
}

{letter}({letter}|{digit})* {
    if (strcmp(yytext, "let") == 0) print_token("LET");
    else if (strcmp(yytext, "mut") == 0) print_token("MUT");
    else if (strcmp(yytext, "fn") == 0) print_token("FUNC");
    else if (strcmp(yytext, "print") == 0) print_token("PRINT");
    else if (strcmp(yytext, "println") == 0) print_token("PRINTLN");
    else if (strcmp(yytext, "if") == 0) print_token("IF");
    else if (strcmp(yytext, "else") == 0) print_token("ELSE");
    else if (strcmp(yytext, "while") == 0) print_token("WHILE");
    else if (strcmp(yytext, "loop") == 0) print_token("LOOP");
    else if (strcmp(yytext, "for") == 0) print_token("FOR");
    else if (strcmp(yytext, "in") == 0) print_token("IN");
    else if (strcmp(yytext, "break") == 0) print_token("BREAK");
    else if (strcmp(yytext, "return") == 0) print_token("RETURN");
    else if (strcmp(yytext, "as") == 0) print_token("AS");
    else if (strcmp(yytext, "true") == 0) print_token("TRUE");
    else if (strcmp(yytext, "false") == 0) print_token("FALSE");
    else if (strcmp(yytext, "i32") == 0 || strcmp(yytext, "i64") == 0) print_token("INT");
    else if (strcmp(yytext, "f32") == 0 || strcmp(yytext, "f64") == 0) print_token("FLOAT");
    else if (strcmp(yytext, "bool") == 0) print_token("BOOL");
    else print_token("IDENT");
}

"<<"    { print_token("LSHIFT"); }
">>"    { print_token("RSHIFT"); }
"<="    { print_token("LEQ"); }
"<"     { print_token("LSS"); }
">="    { print_token("GEQ"); }
">"     { print_token("GTR"); }
"=="    { print_token("EQL"); }
"!="    { print_token("NEQ"); }
"&&"    { print_token("LAND"); }
"||"    { print_token("LOR"); }
"&"     { print_token("BAND"); }
"+="    { print_token("ADD_ASSIGN"); }
"-="    { print_token("SUB_ASSIGN"); }
"*="    { print_token("MUL_ASSIGN"); }
"/="    { print_token("QUO_ASSIGN"); }
"%="    { print_token("REM_ASSIGN"); }
"->"    { print_token("ARROW"); }
".."    { print_token("DOTDOT"); }
"="     { print_token("ASSIGN"); }
"+"     { print_token("ADD"); }
"-"     { print_token("SUB"); }
"*"     { print_token("MUL"); }
"/"     { print_token("QUO"); }
"%"     { print_token("REM"); }
"!"     { print_token("NOT"); }
"("     { print_token("LPAREN"); }
")"     { print_token("RPAREN"); }
"{"     { print_token("LBRACE"); }
"}"     { print_token("RBRACE"); }
"["     { print_token("LBRACK"); }
"]"     { print_token("RBRACK"); }
","     { print_token("COMMA"); }
":"     { print_token("COLON"); }
";"     { print_token("SEMICOLON"); }

[ \t]+  { /* skip whitespace */ }

\n      {
    print_token("NEWLINE");
    line_num++;
}

<<EOF>> {
    line_num++;
    yyterminate();
}

. { /* skip other characters */ }

%%

/*  C Code section */
int yywrap(void)
{
   return 1;
}

int main(int argc, char *argv[])
{
   if (argc == 2) {
       yyin = fopen(argv[1], "r");
   } else {
       yyin = stdin;
   }
   yylex();
   printf("\nFinish scanning,\n");
   printf("total line: %d\n", line_num);
   printf("comment line: %d\n", comment_num);
   fclose(yyin);
   return 0;
}
