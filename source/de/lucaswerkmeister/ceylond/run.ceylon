import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}

shared void run() {
    start {
        ReadCallback? instance(void write(ByteBuffer content, WriteCallback callback), void close()) {
            print("started instance");
            write(utf8.encodeBuffer("Hello, World! Please supply your name.\n"), () { print("first write done"); });
            variable Boolean haveName = false;
            print("don’t have a name yet");
            return (ByteBuffer content) {
                print("application read something");
                if (haveName) {
                    print("application read a second transmission");
                    write(utf8.encodeBuffer("Thank you, once is quite enough.\n"), () => print("weird write done"));
                } else {
                    String name = utf8.decode(content);
                    haveName = true;
                    write(utf8.encodeBuffer("Greetings, ``name``!\n"), () { print("second write done, closing"); close(); });
                }
            };
        }
    };
}
