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

    typedef struct { char* type; int addr; } SymbolInfo;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* func_sig, int mut);
    static SymbolInfo lookup_symbol_info(char* name);
    static void dump_symbol();
    static int variable_exists(char* name);
    static void check_mutable(char* name);
    
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
    int label_counter = 0;
    int if_label_stack[100]; // Stack to track if statement labels
    int if_label_top = -1;

    FILE *jout = NULL;
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
        char *type; // "i32" or "f32"
        char *code; // codegen string
    } expr;
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
%type <expr> Type
%type <expr> Expression
%type <expr> CastExpression
%type <expr> LogicalOrExpression
%type <expr> LogicalAndExpression
%type <expr> RelationalExpression
%type <expr> AdditiveExpression
%type <expr> MultiplicativeExpression
%type <expr> UnaryExpression
%type <expr> PrimaryExpression

/* Operator precedence and associativity */
%left LOR
%left LAND
%left '>' '<' GEQ LEQ EQL NEQ
%left '+' '-'
%left '*' '/' '%'
%left LSHIFT RSHIFT
%left AS
%right '!' NEG
%left '(' ')'

/* Handle dangling else */
%nonassoc IFX
%nonassoc ELSE

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
        // Only handle println with string literal for now
        fprintf(jout, "    getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        fprintf(jout, "    ldc \"%s\" ;\n", $4);
        fprintf(jout, "    invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
    }
    | PRINTLN '(' Expression ')' ';' {
        // 根據型別產生對應 print 指令
        fprintf(jout, "    getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        fprintf(jout, "%s", $3.code);
        if (strcmp($3.type, "i32") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/println(I)V\n");
        } else if (strcmp($3.type, "f32") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/println(F)V\n");
        } else if (strcmp($3.type, "bool") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/println(Z)V\n");
        } else if (strcmp($3.type, "str") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }
    }
    | PRINT '(' Expression ')' ';' {
        fprintf(jout, "    getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        fprintf(jout, "%s", $3.code);
        if (strcmp($3.type, "i32") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/print(I)V\n");
        } else if (strcmp($3.type, "f32") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/print(F)V\n");
        } else if (strcmp($3.type, "bool") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/print(Z)V\n");
        } else if (strcmp($3.type, "str") == 0) {
            fprintf(jout, "    invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
        }
    }
    | LET ID ':' Type '=' Expression ';' {
        insert_symbol($2, $4.type, "-", 0);
        int addr = lookup_symbol_info($2).addr;
        if (strcmp($4.type, "i32") == 0) {
            fprintf(jout, "%s    istore %d\n", $6.code, addr);
        } else if (strcmp($4.type, "f32") == 0) {
            fprintf(jout, "%s    fstore %d\n", $6.code, addr);
        } else if (strcmp($4.type, "str") == 0) {
            fprintf(jout, "%s    astore %d\n", $6.code, addr);
        } else if (strcmp($4.type, "bool") == 0) {
            fprintf(jout, "%s    istore %d\n", $6.code, addr);
        }
    }
    | LET ID ':' Type ';' {
        insert_symbol($2, $4.type, "-", 0);
        int addr = lookup_symbol_info($2).addr;
        if (strcmp($4.type, "i32") == 0) {
            fprintf(jout, "    ldc 0\n    istore %d\n", addr);
        } else if (strcmp($4.type, "f32") == 0) {
            fprintf(jout, "    ldc 0.0\n    fstore %d\n", addr);
        }
    }
    | LET ID '=' Expression ';' {
        char* type = $4.type;
        insert_symbol($2, type, "-", 0);
        int addr = lookup_symbol_info($2).addr;
        if (strcmp(type, "i32") == 0) {
            fprintf(jout, "%s    istore %d\n", $4.code, addr);
        } else if (strcmp(type, "f32") == 0) {
            fprintf(jout, "%s    fstore %d\n", $4.code, addr);
        } else if (strcmp(type, "str") == 0) {
            fprintf(jout, "%s    astore %d\n", $4.code, addr);
        } else if (strcmp(type, "bool") == 0) {
            fprintf(jout, "%s    istore %d\n", $4.code, addr);
        }
    }
    | LET MUT ID ':' Type '=' Expression ';' {
        insert_symbol($3, $5.type, "-", 1);
        int addr = lookup_symbol_info($3).addr;
        if (strcmp($5.type, "i32") == 0) {
            fprintf(jout, "%s    istore %d\n", $7.code, addr);
        } else if (strcmp($5.type, "f32") == 0) {
            fprintf(jout, "%s    fstore %d\n", $7.code, addr);
        } else if (strcmp($5.type, "str") == 0) {
            fprintf(jout, "%s    astore %d\n", $7.code, addr);
        } else if (strcmp($5.type, "bool") == 0) {
            fprintf(jout, "%s    istore %d\n", $7.code, addr);
        }
    }
    | LET MUT ID ':' Type ';' {
        insert_symbol($3, $5.type, "-", 1);
        int addr = lookup_symbol_info($3).addr;
        if (strcmp($5.type, "i32") == 0) {
            fprintf(jout, "    ldc 0\n    istore %d\n", addr);
        } else if (strcmp($5.type, "f32") == 0) {
            fprintf(jout, "    ldc 0.0\n    fstore %d\n", addr);
        } else if (strcmp($5.type, "str") == 0) {
            fprintf(jout, "    ldc \"\"\n    astore %d\n", addr);
        } else if (strcmp($5.type, "bool") == 0) {
            fprintf(jout, "    ldc 0\n    istore %d\n", addr);
        }
    }
    | LET MUT ID '=' Expression ';' {
        char* type = $5.type;
        insert_symbol($3, type, "-", 1);
        int addr = lookup_symbol_info($3).addr;
        if (strcmp(type, "i32") == 0) {
            fprintf(jout, "%s    istore %d\n", $5.code, addr);
        } else if (strcmp(type, "f32") == 0) {
            fprintf(jout, "%s    fstore %d\n", $5.code, addr);
        } else if (strcmp(type, "str") == 0) {
            fprintf(jout, "%s    astore %d\n", $5.code, addr);
        } else if (strcmp(type, "bool") == 0) {
            fprintf(jout, "%s    istore %d\n", $5.code, addr);
        }
    }
    | ID '=' Expression ';' {
        if (variable_exists($1)) {
            int addr = lookup_symbol_info($1).addr;
            char* type = lookup_symbol_info($1).type;
            if (strcmp(type, "i32") == 0) {
                fprintf(jout, "%s    istore %d\n", $3.code, addr);
            } else if (strcmp(type, "f32") == 0) {
                fprintf(jout, "%s    fstore %d\n", $3.code, addr);
            } else if (strcmp(type, "str") == 0) {
                fprintf(jout, "%s    astore %d\n", $3.code, addr);
            } else if (strcmp(type, "bool") == 0) {
                fprintf(jout, "%s    istore %d\n", $3.code, addr);
            }
        }
        check_mutable($1);
    }
    | ID ADD_ASSIGN Expression ';' {
        check_mutable($1);
        if (variable_exists($1)) {
            SymbolInfo info = lookup_symbol_info($1);
            if (strcmp(info.type, "i32") == 0) {
                fprintf(jout, "    iload %d\n%s    iadd\n    istore %d\n", info.addr, $3.code, info.addr);
            } else if (strcmp(info.type, "f32") == 0) {
                fprintf(jout, "    fload %d\n%s    fadd\n    fstore %d\n", info.addr, $3.code, info.addr);
            }
        }
    }
    | ID SUB_ASSIGN Expression ';' {
        check_mutable($1);
        if (variable_exists($1)) {
            SymbolInfo info = lookup_symbol_info($1);
            if (strcmp(info.type, "i32") == 0) {
                fprintf(jout, "    iload %d\n%s    isub\n    istore %d\n", info.addr, $3.code, info.addr);
            } else if (strcmp(info.type, "f32") == 0) {
                fprintf(jout, "    fload %d\n%s    fsub\n    fstore %d\n", info.addr, $3.code, info.addr);
            }
        }
    }
    | ID MUL_ASSIGN Expression ';' {
        check_mutable($1);
        if (variable_exists($1)) {
            SymbolInfo info = lookup_symbol_info($1);
            if (strcmp(info.type, "i32") == 0) {
                fprintf(jout, "    iload %d\n%s    imul\n    istore %d\n", info.addr, $3.code, info.addr);
            } else if (strcmp(info.type, "f32") == 0) {
                fprintf(jout, "    fload %d\n%s    fmul\n    fstore %d\n", info.addr, $3.code, info.addr);
            }
        }
    }
    | ID DIV_ASSIGN Expression ';' {
        check_mutable($1);
        if (variable_exists($1)) {
            SymbolInfo info = lookup_symbol_info($1);
            if (strcmp(info.type, "i32") == 0) {
                fprintf(jout, "    iload %d\n%s    idiv\n    istore %d\n", info.addr, $3.code, info.addr);
            } else if (strcmp(info.type, "f32") == 0) {
                fprintf(jout, "    fload %d\n%s    fdiv\n    fstore %d\n", info.addr, $3.code, info.addr);
            }
        }
    }
    | ID REM_ASSIGN Expression ';' {
        check_mutable($1);
        if (variable_exists($1)) {
            SymbolInfo info = lookup_symbol_info($1);
            if (strcmp(info.type, "i32") == 0) {
                fprintf(jout, "    iload %d\n%s    irem\n    istore %d\n", info.addr, $3.code, info.addr);
            }
        }
    }
    | '{' { create_symbol(); } StatementList '}' { 
        dump_symbol(); 
        scope_level--; 
    }
    | IfStatement
    | WhileStatement
    | NEWLINE
;

IfStatement
    : IF Expression {
        // Store expression and generate conditional jump
        int else_label = ++label_counter;
        int end_label = ++label_counter;
        if_label_stack[++if_label_top] = else_label;
        if_label_stack[++if_label_top] = end_label;
        fprintf(jout, "%s    ifeq L%d\n", $2.code, else_label);
    } Block ElsePart {
        // Generate final end label
        int end_label = if_label_stack[if_label_top--];
        fprintf(jout, "L%d:\n", end_label);
    }
;

ElsePart
    : ELSE {
        // Generate jump to end and else label
        int end_label = if_label_stack[if_label_top];
        int else_label = if_label_stack[if_label_top-1];
        fprintf(jout, "    goto L%d\nL%d:\n", end_label, else_label);
    } Block
    | /* empty */ {
        // No else part - just generate the else label (which becomes the end)
        int end_label = if_label_stack[if_label_top];
        int else_label = if_label_stack[if_label_top-1];
        if_label_stack[if_label_top-1] = end_label; // Reuse end label as else label
        fprintf(jout, "L%d:\n", else_label);
    }
;

WhileStatement
    : WHILE {
        // Generate loop start label
        int start_label = ++label_counter;
        int end_label = ++label_counter;
        if_label_stack[++if_label_top] = start_label;
        if_label_stack[++if_label_top] = end_label;
        fprintf(jout, "L%d:\n", start_label);
    } Expression {
        // Generate conditional jump - if false, exit loop
        int end_label = if_label_stack[if_label_top];
        fprintf(jout, "%s    ifeq L%d\n", $3.code, end_label);
    } Block {
        // Generate jump back to start and end label
        int end_label = if_label_stack[if_label_top--];
        int start_label = if_label_stack[if_label_top--];
        fprintf(jout, "    goto L%d\nL%d:\n", start_label, end_label);
    }
;

Block
    : '{' { create_symbol(); } StatementList '}' { 
        dump_symbol(); 
        scope_level--; 
    }
;

Type
    : INT { $$.type = strdup("i32"); $$.code = strdup(""); }
    | FLOAT { $$.type = strdup("f32"); $$.code = strdup(""); }
    | BOOL { $$.type = strdup("bool"); $$.code = strdup(""); }
    | STR { $$.type = strdup("str"); $$.code = strdup(""); }
    | '&' STR { $$.type = strdup("str"); $$.code = strdup(""); }
    | '[' Type ';' INT_LIT ']' { printf("INT_LIT %d\n", $4); $$.type = strdup("array"); $$.code = strdup(""); }
;

Expression
    : LogicalOrExpression { $$ = $1; }
;

LogicalOrExpression
    : LogicalOrExpression LOR LogicalAndExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        sprintf(code, "%s%s    ior\n", $1.code, $3.code);
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | LogicalAndExpression { $$.type = $1.type; $$.code = $1.code; }
;

LogicalAndExpression
    : LogicalAndExpression LAND RelationalExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        sprintf(code, "%s%s    iand\n", $1.code, $3.code);
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | RelationalExpression { $$.type = $1.type; $$.code = $1.code; }
;

RelationalExpression
    : RelationalExpression '>' AdditiveExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        int label_id = label_counter++;
        if (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s%s    fcmpg\n    ifgt L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        } else {
            sprintf(code, "%s%s    if_icmpgt L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        }
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | RelationalExpression '<' AdditiveExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        int label_id = label_counter++;
        if (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s%s    fcmpl\n    iflt L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        } else {
            sprintf(code, "%s%s    if_icmplt L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        }
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | RelationalExpression GEQ AdditiveExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        int label_id = label_counter++;
        if (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s%s    fcmpg\n    ifge L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        } else {
            sprintf(code, "%s%s    if_icmpge L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        }
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | RelationalExpression LEQ AdditiveExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        int label_id = label_counter++;
        if (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s%s    fcmpl\n    ifle L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        } else {
            sprintf(code, "%s%s    if_icmple L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        }
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | RelationalExpression EQL AdditiveExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        int label_id = label_counter++;
        if (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s%s    fcmpl\n    ifeq L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        } else {
            sprintf(code, "%s%s    if_icmpeq L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        }
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | RelationalExpression NEQ AdditiveExpression { 
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        int label_id = label_counter++;
        if (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s%s    fcmpl\n    ifne L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        } else {
            sprintf(code, "%s%s    if_icmpne L_true_%d\n    ldc 0\n    goto L_end_%d\nL_true_%d:\n    ldc 1\nL_end_%d:\n", 
                    $1.code, $3.code, label_id, label_id, label_id, label_id);
        }
        $$.type = strdup("bool"); 
        $$.code = code;
    }
    | AdditiveExpression { $$.type = $1.type; $$.code = $1.code; }
;

AdditiveExpression
    : AdditiveExpression '+' MultiplicativeExpression {
        char *type = (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) ? "f32" : "i32";
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        if (strcmp(type, "f32") == 0) {
            // If result is float, convert operands if necessary
            if (strcmp($1.type, "i32") == 0 && strcmp($3.type, "f32") == 0) {
                sprintf(code, "%s    i2f\n%s    fadd\n", $1.code, $3.code);
            } else if (strcmp($1.type, "f32") == 0 && strcmp($3.type, "i32") == 0) {
                sprintf(code, "%s%s    i2f\n    fadd\n", $1.code, $3.code);
            } else {
                sprintf(code, "%s%s    fadd\n", $1.code, $3.code);
            }
        } else {
            sprintf(code, "%s%s    iadd\n", $1.code, $3.code);
        }
        $$.type = strdup(type);
        $$.code = code;
    }
    | AdditiveExpression '-' MultiplicativeExpression {
        char *type = (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) ? "f32" : "i32";
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        if (strcmp(type, "f32") == 0) {
            // If result is float, convert operands if necessary
            if (strcmp($1.type, "i32") == 0 && strcmp($3.type, "f32") == 0) {
                sprintf(code, "%s    i2f\n%s    fsub\n", $1.code, $3.code);
            } else if (strcmp($1.type, "f32") == 0 && strcmp($3.type, "i32") == 0) {
                sprintf(code, "%s%s    i2f\n    fsub\n", $1.code, $3.code);
            } else {
                sprintf(code, "%s%s    fsub\n", $1.code, $3.code);
            }
        } else {
            sprintf(code, "%s%s    isub\n", $1.code, $3.code);
        }
        $$.type = strdup(type);
        $$.code = code;
    }
    | MultiplicativeExpression { $$ = $1; }
;

MultiplicativeExpression
    : MultiplicativeExpression '*' UnaryExpression {
        char *type = (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) ? "f32" : "i32";
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        if (strcmp(type, "f32") == 0) {
            // If result is float, convert operands if necessary
            if (strcmp($1.type, "i32") == 0 && strcmp($3.type, "f32") == 0) {
                sprintf(code, "%s    i2f\n%s    fmul\n", $1.code, $3.code);
            } else if (strcmp($1.type, "f32") == 0 && strcmp($3.type, "i32") == 0) {
                sprintf(code, "%s%s    i2f\n    fmul\n", $1.code, $3.code);
            } else {
                sprintf(code, "%s%s    fmul\n", $1.code, $3.code);
            }
        } else {
            sprintf(code, "%s%s    imul\n", $1.code, $3.code);
        }
        $$.type = strdup(type);
        $$.code = code;
    }
    | MultiplicativeExpression '/' UnaryExpression {
        char *type = (strcmp($1.type, "f32") == 0 || strcmp($3.type, "f32") == 0) ? "f32" : "i32";
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 128);
        if (strcmp(type, "f32") == 0) {
            // If result is float, convert operands if necessary
            if (strcmp($1.type, "i32") == 0 && strcmp($3.type, "f32") == 0) {
                sprintf(code, "%s    i2f\n%s    fdiv\n", $1.code, $3.code);
            } else if (strcmp($1.type, "f32") == 0 && strcmp($3.type, "i32") == 0) {
                sprintf(code, "%s%s    i2f\n    fdiv\n", $1.code, $3.code);
            } else {
                sprintf(code, "%s%s    fdiv\n", $1.code, $3.code);
            }
        } else {
            sprintf(code, "%s%s    idiv\n", $1.code, $3.code);
        }
        $$.type = strdup(type);
        $$.code = code;
    }
    | MultiplicativeExpression '%' UnaryExpression {
        char *code = (char*)malloc(strlen($1.code) + strlen($3.code) + 64);
        sprintf(code, "%s%s    irem\n", $1.code, $3.code);
        $$.type = strdup("i32");
        $$.code = code;
    }
    | UnaryExpression { $$ = $1; }
;

UnaryExpression
    : '!' UnaryExpression {
        char *code = (char*)malloc(strlen($2.code) + 64);
        sprintf(code, "%s    ldc 1\n    ixor\n", $2.code);
        $$.type = strdup("bool");
        $$.code = code;
    }
    | '-' UnaryExpression %prec NEG {
        char *code = (char*)malloc(strlen($2.code) + 64);
        if (strcmp($2.type, "f32") == 0) {
            sprintf(code, "%s    fneg\n", $2.code);
        } else {
            sprintf(code, "%s    ineg\n", $2.code);
        }
        $$.type = strdup($2.type);
        $$.code = code;
    }
    | CastExpression { $$ = $1; }
;

CastExpression
    : CastExpression AS Type {
        char *code = (char*)malloc(strlen($1.code) + 64);
        if (strcmp($1.type, "i32") == 0 && strcmp($3.type, "f32") == 0) {
            sprintf(code, "%s    i2f\n", $1.code);
            $$.type = strdup("f32"); 
            $$.code = code;
        } else if (strcmp($1.type, "f32") == 0 && strcmp($3.type, "i32") == 0) {
            sprintf(code, "%s    f2i\n", $1.code);
            $$.type = strdup("i32"); 
            $$.code = code;
        } else {
            $$.type = strdup($3.type); 
            $$.code = strdup($1.code);
        }
    }
    | PrimaryExpression { $$.type = $1.type; $$.code = $1.code; }
;

PrimaryExpression
    : INT_LIT { char buf[64]; sprintf(buf, "    ldc %d\n", $1); $$.type = strdup("i32"); $$.code = strdup(buf); }
    | FLOAT_LIT { char buf[64]; sprintf(buf, "    ldc %f\n", $1); $$.type = strdup("f32"); $$.code = strdup(buf); }
    | '"' STRING_LIT '"' { 
        char buf[256]; 
        sprintf(buf, "    ldc \"%s\"\n", $2); 
        $$.type = strdup("str"); 
        $$.code = strdup(buf); 
    }
    | '"' '"' { 
        char buf[64]; 
        sprintf(buf, "    ldc \"\"\n"); 
        $$.type = strdup("str"); 
        $$.code = strdup(buf); 
    }
    | TRUE { $$.type = strdup("bool"); $$.code = strdup("    ldc 1\n"); }
    | FALSE { $$.type = strdup("bool"); $$.code = strdup("    ldc 0\n"); }
    | ID {
        SymbolInfo info = lookup_symbol_info($1);
        $$.type = strdup(info.type);
        char buf[64];
        if (strcmp(info.type, "i32") == 0) {
            sprintf(buf, "    iload %d\n", info.addr);
        } else if (strcmp(info.type, "f32") == 0) {
            sprintf(buf, "    fload %d\n", info.addr);
        } else if (strcmp(info.type, "str") == 0) {
            sprintf(buf, "    aload %d\n", info.addr);
        } else if (strcmp(info.type, "bool") == 0) {
            sprintf(buf, "    iload %d\n", info.addr);
        } else {
            sprintf(buf, "");
        }
        $$.code = strdup(buf);
    }
    | ID { lookup_symbol_info($1); } '[' Expression ']' {
        $$.type = strdup("array"); $$.code = strdup("");
    }
    | '[' ArrayElements ']' {
        $$.type = strdup("array"); $$.code = strdup("");
    }
    | '(' Expression ')' { $$.type = $2.type; $$.code = strdup($2.code); }
;

ArrayElements
    : ArrayElements ',' Expression
    | Expression
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

    jout = fopen("hw3.j", "w");
    // Emit Jasmin header for Main class and main method
    fprintf(jout, ".source Main.j\n");
    fprintf(jout, ".class public Main\n");
    fprintf(jout, ".super java/lang/Object\n\n");
    fprintf(jout, ".method public static main([Ljava/lang/String;)V\n");
    fprintf(jout, ".limit stack 100\n");
    fprintf(jout, ".limit locals 100\n");

    yylineno = 1;
    yyparse();

    // Emit return and end method for main
    fprintf(jout, "    return\n");
    fprintf(jout, ".end method\n");

    printf("Total lines: %d\n", yylineno - 1);
    fclose(yyin);
    fclose(jout);
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

static SymbolInfo lookup_symbol_info(char* name) {
    for (int i = scope_level - 1; i >= 0; i--) {
        Symbol* current = symbol_table[i];
        while (current) {
            if (strcmp(current->name, name) == 0) {
                SymbolInfo info;
                info.type = current->type;
                info.addr = current->addr;
                return info;
            }
            current = current->next;
        }
    }
    SymbolInfo info;
    info.type = strdup("undefined");
    info.addr = -1;
    printf("error:%d: undefined: %s\n", yylineno, name);
    return info;
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

static int variable_exists(char* name) {
    // Search from current scope to global scope
    for (int i = scope_level - 1; i >= 0; i--) {
        Symbol* current = symbol_table[i];
        while (current) {
            if (strcmp(current->name, name) == 0) {
                return 1; // Found
            }
            current = current->next;
        }
    }
    return 0; // Not found
}

static void check_mutable(char* name) {
    // Search from current scope to global scope
    for (int i = scope_level - 1; i >= 0; i--) {
        Symbol* current = symbol_table[i];
        while (current) {
            if (strcmp(current->name, name) == 0) {
                if (current->mut == 0) {
                    printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", yylineno, name);
                }
                return;
            }
            current = current->next;
        }
    }
    // If we reach here, the variable is undefined
    printf("error:%d: undefined: %s\n", yylineno, name);
}