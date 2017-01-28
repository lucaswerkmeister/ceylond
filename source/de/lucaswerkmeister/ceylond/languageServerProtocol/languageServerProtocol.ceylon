import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    ascii,
    utf8
}
import ceylon.collection {
    HashMap,
    MutableMap
}
import ceylon.json {
    StringPrinter,
    Value,
    parse
}
import de.lucaswerkmeister.ceylond.core {
    ReadCallback,
    ServerExceptionHandler,
    SocketExceptionHandler,
    WriteCallback,
    logAndAbort,
    start
}

shared alias ReadJsonCallback => Anything(Value);

shared [ReadCallback, SocketExceptionHandler]? makeLanguageServerProtocolInstance(
"This function is called whenever a new connection to the socket is opened.
 It works just like [[start.instance]],
 except that [[write]] takes a JSON value instead of a byte buffer
 and the read callback is only called with complete individual JSON values.
 If an unknown header is received,
 the received text does not parse to valid JSON,
 or another protocol error occurs,
 an error is logged and the connection is immediately closed.
 (The exception handler returned by [[instance]] is not consulted in this case.)"
[ReadJsonCallback, SocketExceptionHandler]? instance(
"Write a packet with the given [[content]] and [[type]] to the socket."
void write(Value content, WriteCallback callback),
void close()))(void write(ByteBuffer content, WriteCallback callback), void close()) {
    value inst = instance {
        void write(Value content, WriteCallback callback) {
            value printer = StringPrinter { pretty = true; }; // TODO pretty?
            printer.printValue(content);
            value encodedContent = utf8.encodeBuffer(printer.string);
            write(ascii.encodeBuffer("Content-Length: ``encodedContent.available``\r\n"), noop);
            write(ascii.encodeBuffer("Content-type: application/json; charset=utf-8\r\n\r\n"), noop);
            write(encodedContent, callback);
        }
        close = close;
    };
    if (exists [read, handler] = inst) {
        "This string builder holds the header characters while the headers are being received."
        StringBuilder partialHeaders = StringBuilder();
        "This buffer is reallocated for each new message once the headers are complete
         and holds the actual JSON content.
         Its existence indicates that bytes belong to the content, not the headers.
         When it is full, the message is decoded and dispatched,
         and this buffer is reset to [[null]]."
        variable ByteBuffer? jsonContent = null;
        "This map holds the headers as map from header name to content
         once they have been fully received."
        MutableMap<String, String> parsedHeaders = HashMap<String, String>();
        void readMessage(ByteBuffer content) {
            if (!jsonContent exists) {
                while (content.hasAvailable) {
                    value codepoint = content.get().unsigned;
                    if (codepoint > 127) {
                        throw NonAsciiHeaderCharacterException(codepoint);
                    }
                    partialHeaders.appendCharacter(codepoint.character);
                    if (partialHeaders.endsWith("\r\n\r\n")) {
                        String->String parseHeader(String header) {
                            if (exists colonIndex = header.firstOccurrence(':')) {
                                return header[...colonIndex-1]->header[colonIndex+2...]; // skip colon and space after it
                            } else {
                                throw HeaderWithoutColonException(header);
                            }
                        }
                        parsedHeaders.putAll(partialHeaders.string.lines.exceptLast.exceptLast.map(parseHeader)); // TODO yes, lines isn’t quite correct because of solo \r or \n, fuck it
                        if (exists contentLengthHeader = parsedHeaders["Content-Length"]) {
                            if (exists contentLength = parseInteger(contentLengthHeader)) {
                                jsonContent = ByteBuffer.ofSize(contentLength);
                                break;
                            } else {
                                throw InvalidContentLengthException(contentLengthHeader);
                            }
                        } else {
                            throw NoContentLengthException();
                        }
                    }
                }
            }
            if (exists jsonContentBuffer = jsonContent) {
                while (content.hasAvailable && jsonContentBuffer.hasAvailable) {
                    jsonContentBuffer.put(content.get());
                }
                if (!jsonContentBuffer.hasAvailable) {
                    jsonContentBuffer.flip();
                    try {
                        String jsonString;
                        try {
                            jsonString = utf8.decode(jsonContentBuffer);
                        } catch (Exception e) {
                            throw DecodeContentException(e);
                        }
                        Value jsonValue;
                        try {
                            jsonValue = parse(jsonString);
                        } catch (Exception e) {
                            throw ParseContentException(e);
                        }
                        read(jsonValue);
                    } finally {
                        jsonContent = null;
                        partialHeaders.clear();
                    }
                }
            }
        }
        return [readMessage, handler];
    } else {
        return null;
    }
}

shared void startLanguageServer(
"See [[makeLanguageServerProtocolInstance.instance]]."
[ReadJsonCallback, SocketExceptionHandler]? instance(void write(Value content, WriteCallback callback), void close()),
"See [[start.fd]]."
Integer fd,
"See [[start.handler]]."
ServerExceptionHandler handler = logAndAbort(),
"See [[start.concurrent]]."
Boolean concurrent = true)
        => start {
    instance = makeLanguageServerProtocolInstance {
        instance = instance;
    };
    fd = fd;
    handler = handler;
    concurrent = concurrent;
};
