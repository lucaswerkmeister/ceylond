import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}
import ceylon.logging {
    addLogWriter,
    defaultPriority,
    warn,
    writeSimpleLog
}

shared void run() {
    addLogWriter(writeSimpleLog);
    defaultPriority = warn;
    start {
        [ReadCallback, SocketExceptionHandler]? instance(void write(ByteBuffer content, WriteCallback callback), void close()) {
            log.trace("started instance");
            write(utf8.encodeBuffer("Hello, World! Please supply your name.\n"), () { log.trace("first write done"); });
            variable Boolean haveName = false;
            log.trace("don’t have a name yet");
            void read(ByteBuffer content) {
                log.trace("application read something, length ``content.available``");
                if (haveName) {
                    log.trace("application read a second transmission");
                    write(utf8.encodeBuffer("Thank you, once is quite enough.\n"), () => log.trace("weird write done"));
                } else {
                    String name = utf8.decode(content);
                    haveName = true;
                    write(utf8.encodeBuffer("Greetings, ``name``!\n"), () { log.trace("second write done, closing"); close(); });
                }
            }
            return [read, logAndAbort(`module`)];
        }
        fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
    };
}
