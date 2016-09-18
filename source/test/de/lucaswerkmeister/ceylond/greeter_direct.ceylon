import de.lucaswerkmeister.ceylond {
    WriteCallback,
    start
}
import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}

shared void greeter_direct()
        => start {
            function instance(void write(ByteBuffer content, WriteCallback callback), void close()) {
                write(utf8.encodeBuffer("Hello, World! Please supply your name.\n"), noop);
                void read(ByteBuffer content) {
                    value name = utf8.decodeBuffer(content);
                    write(utf8.encodeBuffer("Greetings, ``name``!\n"), noop);
                    write(utf8.encodeBuffer("Goodbye.\n"), close);
                }
                return [read, logAndDie(`module`)];
            }
            fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
        };
