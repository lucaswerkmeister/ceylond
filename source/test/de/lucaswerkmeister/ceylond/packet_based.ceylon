import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}
import de.lucaswerkmeister.ceylond.core {
    WriteCallback
}
import de.lucaswerkmeister.ceylond.packetBased {
    startPacketBased
}

shared void packet_based()
        => startPacketBased {
    function instance(void write(ByteBuffer content, Integer type, WriteCallback callback), void close()) {
        void readGreeting(ByteBuffer content) {
            value name = utf8.decode(content);
            write(utf8.encodeBuffer("Greetings, ``name``!\n"), 0, noop);
            write(utf8.encodeBuffer("Goodbye.\n"), #FF, close);
        }
        void readCat(ByteBuffer content) {
            write(content, 1, noop);
        }
        void readClose(ByteBuffer content) {
            assert (!content.hasAvailable);
            write(ByteBuffer.ofSize(0), #FF, close);
        }
        void readDie(ByteBuffer content) {
            assert (!content.hasAvailable);
            write(ByteBuffer.ofSize(0), #FFFF, closeAndExit(close));
        }

        value typeMap = map {
            #00->readGreeting,
            #01->readCat,
            #FF->readClose,
            #FFFF->readDie
        };
        return [typeMap, logAndDie(`module`)];
    }
    fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
    lengthSize = 2;
    typeSize = 2;
    maximumLength = 1024;
};
