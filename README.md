# Zig Parsec

During my exploration of functionnal programming, I encountered the notion of Parser Combinator when working on a small compiler for LLVM's Kaleidoscope example.
Later on I saw a few articles and repository for Parser Combinator in Zig ([mecha]([mecha](https://github.com/Hejsil/mecha)), [hexop's blog](https://devlog.hexops.com/2021/zig-parser-combinators-and-why-theyre-awesome/))

This is my approach to implement the concept following closely what can be found in the Parsec library for the Haskell language.

## Quick run down

All parsers are function, with the same base signature:
```zig
fn parser(Stream, std.mem.Allocator, *BaseState) anyerror!Result(T);

fn letterA(stream: Stream, _: std.mem.Allocator, _: *BaseState) anyerror!Result(u8)
{
    if (stream.isEOF()) return Result(u8).unexpected(stream);

    const c = stream.peek();
    if (c == 'A') {
        return Result(u8).success('A', stream.eat(1));
    }
    return Result(u8).unexpected(stream);
}
```

[Stream](/src/Stream.zig) is a simple object that represent a string with some information on the position of the cursor.
[BaseState](/src/UserState.zig) is a object used to define user state variable and state extension (for specialized parser).

