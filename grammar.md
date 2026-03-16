# SRISC Grammar

> TODO: instruction, arithmetic, move, branch as rules

```
// NOTE(1): maybe newlines are insignificant actually (just a token separator like spaces)
//  since there is no ambiguity between each instruction 🤔

// NON-TERMINALS
program     -> start instruction* label_block* end

// NOTE: example doesn't newline after ":", see NOTE(1)
//  label currently does not require an instruction cuz idk, although it can be easily fixed if wanted
label_block -> lbl ":" newline instruction*

// Technically, these can also be terminals? But very awkward to be writing a parsing table and pseudo code without these -.-
instruction -> (arithmetic | move | branch) newline // AKA statement
arithmetic  -> arithmetic_ops reg "," reg "," (reg | NUMBER)
move        -> move_ops reg "," NUMBER "(" reg ")" // NOTE: Idk if pure reg is also allowed
branch      -> branch_ops reg "," reg "," lbl

// TERMINALS
arithmetic_ops -> "add" | "sub" | "and" | "or"
move_ops       -> "ld" | "sd" | "lw" | "sw"
branch_ops     -> "beq" | "bne" | "blt" | "bge"

reg        -> "x" ["0".."31"]
lbl        -> "L" ["0".."10"]

start       -> ".code" newline
end         -> ".end"
newline     -> "\n"

// NOTE: comments are actually ignored by the scanner (lexer)
//       NOT required by the assignment
comment    -> ";" STRING newline
```

```
// NON-TERMINALS
program     -> start A B end
A           -> instruction A | ε
B           -> label_block B | ε

label_block -> lbl ":" newline A

instruction -> arithmetic newline
            |  move newline
            |  branch newline

arithmetic  -> arithmetic_ops reg "," reg "," arithmetic_constant
move        -> move_ops reg "," NUMBER "(" reg ")"
branch      -> branch_ops reg "," reg "," lbl

// TERMINALS
arithmetic_ops -> "add" | "sub" | "and" | "or"
arithmetic_constant -> reg | NUMBER
move_ops       -> "ld" | "sd" | "lw" | "sw"
branch_ops     -> "beq" | "bne" | "blt" | "bge"

reg        -> "x" ["0".."31"]
lbl        -> "L" ["0".."10"]

start       -> ".code" newline
end         -> ".end"
newline     -> "\n"
```

> NOTE: arithmetic_ops, move_ops, branch_ops, arithmetic_constant aren't real terminals/tokens, they are abbreviated to keep the tables small.
However, the tables can be easily fixed for formality by splitting the columns into each individual token


|NON-TERMINAL|FIRST|FOLLOW|
|:-|:-|:-|
|program|{ start }|{ \$ } (\$ is basically end)|
|A|{ ε, arithmetic_ops, move_ops, branch_ops }|{ end, lbl }|
|B|{ ε, lbl }|{ end }|
|label_block|{ lbl }|{ end, lbl }|
|instruction|{ arithmetic_ops, move_ops, branch_ops }|{ end, arithmetic_ops, move_ops, branch_ops, lbl }|
|arithmetic|{ arithmetic_ops }|{ newline }|
|move|{ move_ops }|{ newline }|
|branch|{ brach_ops }|{ newline }|


|  |start|arithmetic_ops|move_ops|branch_ops|reg|lbl|arithmetic_constant|newline|end|
|:-|:-   |:-            |:-      |:-        |:- |:- |:-                 |:-     |:- |
|program|start A B end| | | | | | | | |
|A| |instruction A|instruction A|instruction A| |ε | |  |ε|
|B| | | | | |label_block B| | |ε|
|label_block| | | | | |lbl ":" newline A| | | |
|instruction| |arithmetic newline|move newline|branch newline| | | | | |
|arithmetic| |arithmetic_ops reg "," reg "," arithmetic_constant| | | | | | | |
|move| | |move_ops reg "," NUMBER "(" reg ")"| | | | | | |
|branch| | | |branch_ops reg "," reg "," lbl| | | | | |


```zig
const parsing_table: ParsingTable(Variable, Symbol, []Symbol) = .init();
var stack: Stack(Symbol) = .init(.start);
var input: []Token = Scanner.scan(file);

while (!stack.isEmpty()) {
    const sym = stack.peek();
    const tok = input.peek();

    // end counts as a terminal
    if (sym.isTerminal()) {
        // if valid -> consume token
        if (sym.hasToken(tok)) {
            stack.pop();
            input.advance();
            continue;
        }
        if (sym == .epsilon) {
            stack.pop();
            continue;
        }
        ERROR();
    } else if (sym.isVariable()) {
        if (parsing_table.contains(sym, tok)) {
            stack.pop();
            stack.pushAllReverse(parsing_table.get(sym, tok));
            input.advance();
            continue;
        }
        ERROR();
    }
    ERROR();
}
```

## TODO
- (optional) implement a real parser (runnable) in your chosen language.
