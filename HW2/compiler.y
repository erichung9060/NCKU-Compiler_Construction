/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h"
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* func_sig, int mut);
    static char* lookup_symbol(char* name);
    static void dump_symbol();
    
    /* Symbol table structure */
    typedef struct symbol {
        int index;
        char* name;
        int mut;
        char* type;
        int addr;
        int lineno;
        char* func_sig;
        struct symbol* next;
    } Symbol;
    
    Symbol* symbol_table[10]; // Support up to 10 scope levels
    int symbol_count[10];     // Count of symbols in each scope

    /* Global variables */
    bool HAS_ERROR = false;
    int scope_level = 0;
    int symbol_index = 0;
    int address_counter = 0;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    struct {
        char *type;
        int addr;
    } symbol_info;
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> ID

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type
%type <s_val> Expression
%type <s_val> CastExpression
%type <s_val> LogicalOrExpression
%type <s_val> LogicalAndExpression
%type <s_val> RelationalExpression
%type <s_val> AdditiveExpression
%type <s_val> MultiplicativeExpression
%type <s_val> UnaryExpression
%type <s_val> PrimaryExpression

/* Operator precedence and associativity */
%left LOR
%left LAND
%left '>' '<' GEQ LEQ EQL NEQ
%left '+' '-'
%left '*' '/' '%'
%left AS
%right '!' NEG
%left '(' ')'

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : { create_symbol(); } GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : FUNC ID '(' ')' { 
        printf("func: %s\n", $2); 
        insert_symbol($2, "func", "(V)V", -1);
        create_symbol(); 
    } '{' StatementList '}' { 
        dump_symbol(); 
        scope_level--; 
        dump_symbol(); 
    }
;

StatementList
    : StatementList Statement
    | Statement
    |
;

Statement
    : PRINTLN '(' '"' STRING_LIT '"' ')' ';' {
        printf("STRING_LIT \"%s\"\n", $4);
        printf("PRINTLN str\n");
    }
    | PRINTLN '(' Expression ')' ';' {
        printf("PRINTLN %s\n", $3);
    }
    | PRINT '(' Expression ')' ';' {
        printf("PRINT %s\n", $3);
    }
    | LET ID ':' Type '=' Expression ';' {
        insert_symbol($2, $4, "-", 0);
    }
    | LET ID ':' Type ';' {
        insert_symbol($2, $4, "-", 0);
    }
    | LET MUT ID ':' Type '=' Expression ';' {
        insert_symbol($3, $5, "-", 1);
    }
    | LET MUT ID ':' Type ';' {
        insert_symbol($3, $5, "-", 1);
    }
    | ID '=' Expression ';' {
        printf("ASSIGN\n");
    }
    | ID ADD_ASSIGN Expression ';' {
        printf("ADD_ASSIGN\n");
    }
    | ID SUB_ASSIGN Expression ';' {
        printf("SUB_ASSIGN\n");
    }
    | ID MUL_ASSIGN Expression ';' {
        printf("MUL_ASSIGN\n");
    }
    | ID DIV_ASSIGN Expression ';' {
        printf("DIV_ASSIGN\n");
    }
    | ID REM_ASSIGN Expression ';' {
        printf("REM_ASSIGN\n");
    }
    | '{' { create_symbol(); } StatementList '}' { 
        dump_symbol(); 
        scope_level--; 
    }
    | NEWLINE
;

Type
    : INT { $$ = strdup("i32"); }
    | FLOAT { $$ = strdup("f32"); }
    | BOOL { $$ = strdup("bool"); }
    | STR { $$ = strdup("str"); }
    | '&' STR { $$ = strdup("str"); }
;

Expression
    : LogicalOrExpression { $$ = $1; }
;

LogicalOrExpression
    : LogicalOrExpression LOR LogicalAndExpression {
        printf("LOR\n");
        $$ = strdup("bool");
    }
    | LogicalAndExpression { $$ = $1; }
;

LogicalAndExpression
    : LogicalAndExpression LAND RelationalExpression {
        printf("LAND\n");
        $$ = strdup("bool");
    }
    | RelationalExpression { $$ = $1; }
;

RelationalExpression
    : RelationalExpression '>' AdditiveExpression {
        printf("GTR\n");
        $$ = strdup("bool");
    }
    | RelationalExpression '<' AdditiveExpression {
        printf("LSS\n");
        $$ = strdup("bool");
    }
    | RelationalExpression GEQ AdditiveExpression {
        printf("GEQ\n");
        $$ = strdup("bool");
    }
    | RelationalExpression LEQ AdditiveExpression {
        printf("LEQ\n");
        $$ = strdup("bool");
    }
    | RelationalExpression EQL AdditiveExpression {
        printf("EQL\n");
        $$ = strdup("bool");
    }
    | RelationalExpression NEQ AdditiveExpression {
        printf("NEQ\n");
        $$ = strdup("bool");
    }
    | AdditiveExpression { $$ = $1; }
;

AdditiveExpression
    : AdditiveExpression '+' MultiplicativeExpression {
        printf("ADD\n");
        if (strcmp($1, "f32") == 0 || strcmp($3, "f32") == 0) {
            $$ = strdup("f32");
        } else {
            $$ = strdup("i32");
        }
    }
    | AdditiveExpression '-' MultiplicativeExpression {
        printf("SUB\n");
        if (strcmp($1, "f32") == 0 || strcmp($3, "f32") == 0) {
            $$ = strdup("f32");
        } else {
            $$ = strdup("i32");
        }
    }
    | MultiplicativeExpression { $$ = $1; }
;

MultiplicativeExpression
    : MultiplicativeExpression '*' UnaryExpression {
        printf("MUL\n");
        if (strcmp($1, "f32") == 0 || strcmp($3, "f32") == 0) {
            $$ = strdup("f32");
        } else {
            $$ = strdup("i32");
        }
    }
    | MultiplicativeExpression '/' UnaryExpression {
        printf("DIV\n");
        if (strcmp($1, "f32") == 0 || strcmp($3, "f32") == 0) {
            $$ = strdup("f32");
        } else {
            $$ = strdup("i32");
        }
    }
    | MultiplicativeExpression '%' UnaryExpression {
        printf("REM\n");
        $$ = strdup("i32");
    }
    | UnaryExpression { $$ = $1; }
;

UnaryExpression
    : '!' UnaryExpression {
        printf("NOT\n");
        $$ = strdup("bool");
    }
    | '-' UnaryExpression %prec NEG {
        printf("NEG\n");
        $$ = $2;
    }
    | CastExpression { $$ = $1; }
;

CastExpression
    : CastExpression AS Type {
        if (strcmp($1, "i32") == 0 && strcmp($3, "f32") == 0) {
            printf("i2f\n");
            $$ = strdup("f32");
        } else if (strcmp($1, "f32") == 0 && strcmp($3, "i32") == 0) {
            printf("f2i\n");
            $$ = strdup("i32");
        } else {
            $$ = strdup($3);
        }
    }
    | PrimaryExpression { $$ = $1; }
;

PrimaryExpression
    : INT_LIT {
        printf("INT_LIT %d\n", $1);
        $$ = strdup("i32");
    }
    | FLOAT_LIT {
        printf("FLOAT_LIT %f\n", $1);
        $$ = strdup("f32");
    }
    | '"' STRING_LIT '"' {
        printf("STRING_LIT \"%s\"\n", $2);
        $$ = strdup("str");
    }
    | '"' '"' {
        printf("STRING_LIT \"\"\n");
        $$ = strdup("str");
    }
    | TRUE {
        printf("bool TRUE\n");
        $$ = strdup("bool");
    }
    | FALSE {
        printf("bool FALSE\n");
        $$ = strdup("bool");
    }
    | ID {
        $$ = lookup_symbol($1);
    }
    | '(' Expression ')' {
        $$ = $2;
    }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 1;
    yyparse();

	printf("Total lines: %d\n", yylineno - 1);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", scope_level);
    symbol_table[scope_level] = NULL;
    symbol_count[scope_level] = 0;
    scope_level++;
}

static void insert_symbol(char* name, char* type, char* func_sig, int mut) {
    int current_scope = scope_level - 1;
    
    Symbol* new_symbol = (Symbol*)malloc(sizeof(Symbol));
    new_symbol->index = symbol_count[current_scope];
    new_symbol->name = strdup(name);
    new_symbol->mut = mut;
    new_symbol->type = strdup(type);
    new_symbol->lineno = yylineno;
    new_symbol->func_sig = strdup(func_sig);
    new_symbol->next = symbol_table[current_scope];
    
    if (strcmp(type, "func") == 0) {
        new_symbol->addr = -1;
        printf("> Insert `%s` (addr: %d) to scope level %d\n", name, -1, current_scope);
    } else {
        new_symbol->addr = address_counter++;
        printf("> Insert `%s` (addr: %d) to scope level %d\n", name, new_symbol->addr, current_scope);
    }
    
    symbol_table[current_scope] = new_symbol;
    symbol_count[current_scope]++;
}

static char* lookup_symbol(char* name) {
    // Search from current scope to global scope
    for (int i = scope_level - 1; i >= 0; i--) {
        Symbol* current = symbol_table[i];
        while (current) {
            if (strcmp(current->name, name) == 0) {
                printf("IDENT (name=%s, address=%d)\n", name, current->addr);
                return strdup(current->type);
            }
            current = current->next;
        }
    }
    printf("IDENT (name=%s, address=-1)\n", name); // Not found
    return strdup("unknown");
}

static void dump_symbol() {
    int current_scope = scope_level - 1;
    printf("\n> Dump symbol table (scope level: %d)\n", current_scope);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    
    // Collect symbols in reverse order (to match expected output)
    Symbol* symbols[100];
    int count = 0;
    Symbol* current = symbol_table[current_scope];
    while (current) {
        symbols[count++] = current;
        current = current->next;
    }
    
    // Print in reverse order
    for (int i = count - 1; i >= 0; i--) {
        Symbol* sym = symbols[i];
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
                sym->index, sym->name, sym->mut, sym->type, 
                sym->addr, sym->lineno, sym->func_sig);
    }
}
