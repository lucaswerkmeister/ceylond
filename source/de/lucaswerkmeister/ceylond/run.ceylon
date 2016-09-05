import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}
import ceylon.logging {
    addLogWriter,
    defaultPriority,
    trace,
    writeSimpleLog
}

shared void run() {
    addLogWriter(writeSimpleLog);
    defaultPriority = trace;
    start {
        [ReadCallback, SocketExceptionHandler]? instance(void write(ByteBuffer content, WriteCallback callback), void close()) {
            log.trace("started instance");
            write(utf8.encodeBuffer("Hello, World! Please supply your name.\n"), () { log.trace("first write done"); });
            variable Boolean haveName = false;
            log.trace("don’t have a name yet");
            void read(ByteBuffer content) {
                log.trace("application read something");
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
        fd = 3;
    };
}
