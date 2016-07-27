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
            write(utf8.encodeBuffer("Hello, World! Please supply your name.\n"), (i) { print("first write done"); print(i); });
            variable Boolean haveName = false;
            print("don’t have a name yet");
            return (ByteBuffer content) {
                print("application read something");
                if (haveName) {
                    print("application read a second transmission");
                    write(utf8.encodeBuffer("Thank you, once is quite enough.\n"), (i) => print("weird write done"));
                } else {
                    String name = utf8.decode(content);
                    haveName = true;
                    write(utf8.encodeBuffer("Greetings, ``name``!\n"), (i) { print("second write done, closing"); close(); });
                }
            };
        }
    };
}
