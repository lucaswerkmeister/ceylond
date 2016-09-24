import de.lucaswerkmeister.ceylond {
    WriteCallback,
    startRecordBased
}

shared void greeter_record()
        => startRecordBased {
            function instance(void write(String record, WriteCallback callback), void close()) {
                write("Hello, World! Please supply your name.", noop);
                void read(String name) {
                    write("Greetings, ``name``!", noop);
                    write("Goodbye.", closeAndExit(close));
                }
                return [read, logAndDie(`module`)];
            }
            fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
        };
