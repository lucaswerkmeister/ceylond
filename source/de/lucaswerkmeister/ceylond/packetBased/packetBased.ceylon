import ceylon.buffer {
    ByteBuffer
}
import ceylon.logging {
    logger
}
import de.lucaswerkmeister.ceylond.core {
    ReadCallback,
    ReadCallbackException,
    ServerExceptionHandler,
    SocketException,
    SocketExceptionHandler,
    WriteCallback,
    logAndAbort,
    start
}

"A correspondence from packet type (an unsigned [[Integer]]) to read callback for packets of this type.
 Despite the name, this need not be a [[Map]].

 A type map may, for exammple, be constructed with [[Array]] or [[map]]."
shared alias TypeMap => Correspondence<Integer, ReadCallback>;

"Create an instance for [[start]] that reads and writes packets." // TODO improve doc
see (`function startPacketBased`)
shared [ReadCallback, SocketExceptionHandler]? makePacketBasedInstance(
"This function is called whenever a new connection to the socket is opened.
 It works just like [[start.instance]],
 except that [[write]] also takes a packet type
 and the read callback is not a single function, but a [[TypeMap]].
 If a packet with an unknown type (not [[defined|Correspondence.defines]] by the type map) is returned,
 an error is logged and the connection is immediately closed.
 (The exception handler returned by [[instance]] is not consulted in this case.)"
[TypeMap, SocketExceptionHandler]? instance(
"Write a packet with the given [[content]] and [[type]] to the socket."
void write(ByteBuffer content, Integer type, WriteCallback callback),
void close()),
    "The size of the packet length in bytes."
    Integer lengthSize = 4,
    "The size of the packet type in bytes.
     Set to 0 to disable packet types completely."
    Integer typeSize = 4,
    "The maximum length for received packets.
     You may want to set this to a lower value than what can be stored within [[lengthSize]] bytes
     to avoid allocating huge amounts of memory on malformed or malicious input.
     If this packet exceeding this length is received,
     an error is logged and the connection is immediately closed.
     (The exception handler returned by [[instance]] is not consulted in this case.)"
    Integer maximumLength = 256^lengthSize - 1)(void write(ByteBuffer content, WriteCallback callback), void close()) {
    "Length must be at least one byte long"
    assert (lengthSize > 0);
    "Type cannot be negative bytes long"
    assert (typeSize >= 0);
    "Lengths above 8 cannot be processed"
    assert (lengthSize <= 8 && typeSize <= 8);
    "Maximum length must be positive and must not exceed highest possible value expressible in lengthSize bytes"
    assert (0 < maximumLength < 256^lengthSize);
    value log = logger(`module`); // TODO remove?
    value inst = instance {
        void write(ByteBuffer content, Integer type, WriteCallback callback) {
            Integer length = content.available;
            log.trace("write packet of length ``length``, type ``type``");
            ByteBuffer toWrite = ByteBuffer.ofSize(lengthSize + typeSize + length);
            writeInteger(length, lengthSize, toWrite);
            writeInteger(type, typeSize, toWrite);
            for (_ in 0:length) {
                toWrite.put(content.get());
            }
            toWrite.flip();
            write(toWrite, callback);
        }
        close = close;
    };
    if (exists [readCorrespondence, handler] = inst) {
        "Constant buffer for the packet length."
        ByteBuffer lengthBuffer = ByteBuffer.ofSize(lengthSize);
        "Constant buffer for the packet type."
        ByteBuffer typeBuffer = ByteBuffer.ofSize(typeSize);
        "Variable buffer for the actual packet contents,
         allocated each time the [[length|lengthBuffer]] has been read.
         [[null]] means that a new buffer must be allocated –
         either because nothing has been read yet,
         or because a full packet was written out."
        variable ByteBuffer? contentBuffer = null;
        void readPacket(ByteBuffer content) {
            while (lengthBuffer.hasAvailable && content.hasAvailable) {
                lengthBuffer.put(content.get());
            }
            while (typeBuffer.hasAvailable && content.hasAvailable) {
                typeBuffer.put(content.get());
            }
            ByteBuffer contBuf;
            if (exists contentBuffer_ = contentBuffer) {
                contBuf = contentBuffer_;
            } else {
                if (!lengthBuffer.hasAvailable) {
                    lengthBuffer.flip();
                    value length = readInteger(lengthBuffer);
                    lengthBuffer.clear();
                    if (length > maximumLength) {
                        throw MaximumLengthExceededException {
                            maximumLength = maximumLength;
                            actualLength = length;
                        };
                    } else {
                        log.trace("allocating packet buffer, size ``length``");
                        contBuf = contentBuffer = ByteBuffer.ofSize(length);
                    }
                } else {
                    "If length buffer is not filled, we must have no more bytes to fill it with"
                    assert (!content.hasAvailable);
                    return;
                }
            }
            while (contBuf.hasAvailable && content.hasAvailable) {
                contBuf.put(content.get());
            }
            if (!contBuf.hasAvailable) {
                // dispatch a packet
                "Type buffer must be filled before filling in any content"
                assert (!typeBuffer.hasAvailable);
                typeBuffer.flip();
                value type = readInteger(typeBuffer);
                typeBuffer.clear();
                contentBuffer = null;
                if (exists read = readCorrespondence[type]) {
                    log.trace("read packet of length ``contBuf.capacity``, type ``type``");
                    contBuf.flip();
                    read(contBuf);
                } else {
                    throw UnknownTypeException {
                        type = type;
                        typeSize = typeSize;
                        knownTypes = readCorrespondence.keys;
                    };
                }
                // continue processing, we might have received several packets in one transmission
                readPacket(content);
            } else {
                "If content buffer is not filled, we must have no more bytes to fill it with"
                assert (!content.hasAvailable);
            }
        }
        Boolean handleOwnExceptions(SocketException exception) {
            if (is ReadCallbackException exception, is PacketProtocolException inner = exception.cause) {
                logger(`module`).error(inner.message, exception);
                return false;
            } else {
                return handler(exception);
            }
        }
        return [readPacket, handleOwnExceptions];
    } else {
        return null;
    }
}

"""Start listening on the socket, reading and writing packets.

   Usage example:

       startPacketBased {
           function instance(void write(ByteBuffer content, Integer type, WriteCallback callback), void close()) {
               void readAuth(ByteBuffer content) { ... }
               void readRemoteInvocation(ByteBuffer content) { ... }
               void readRemoteAccess(ByteBuffer content) { ... }

               value typeMap = map {
                   0->readAuth,
                   #101->readRemoteInvocation,
                   #102->readRemoteAccess
               };
               return [typeMap, logAndAbort(`module`)];
           }
           lengthSize = 2;
           typeSize = 2;
           fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
       };"""
see (`function start`, `function makePacketBasedInstance`)
shared void startPacketBased(
"See [[makePacketBasedInstance.instance]]."
[TypeMap, SocketExceptionHandler]? instance(void write(ByteBuffer content, Integer type, WriteCallback callback), void close()),
"See [[start.fd]]."
Integer fd,
"See [[start.handler]]."
ServerExceptionHandler handler = logAndAbort(),
"See [[start.concurrent]]."
Boolean concurrent = true,
"See [[makePacketBasedInstance.lengthSize]]."
    Integer lengthSize = 4,
    "See [[makePacketBasedInstance.typeSize]]."
    Integer typeSize = 4,
    "See [[makePacketBasedInstance.maximumLength."
    Integer maximumLength = 256^lengthSize - 1)
        => start {
    instance = makePacketBasedInstance {
        instance = instance;
        lengthSize = lengthSize;
        typeSize = typeSize;
        maximumLength = maximumLength;
    };
    fd = fd;
    handler = handler;
    concurrent = concurrent;
};
