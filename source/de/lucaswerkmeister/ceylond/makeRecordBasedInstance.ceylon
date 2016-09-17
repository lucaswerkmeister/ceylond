import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    Charset,
    utf8
}
import ceylon.buffer.codec {
    ErrorStrategy,
    strict
}

"A read callback, to be called with a record string when one full record has been read from the socket."
shared alias ReadRecordCallback => Anything(String);

"Create an instance for [[start]] that reads and writes String *records*,
 separated by a [[record separator|recordSeparator]],
 transferred over the socket using a [[charset]] with an [[error strategy|errorStrategy]]."
aliased ("makeLineBasedInstance")
shared [ReadCallback, SocketExceptionHandler]? makeRecordBasedInstance(
    "This function is called whenever a new connection to the socket is opened.
     It works just like [[start.instance]],
     except that [[write]] appends the record separator and encodes with the [[charset]],
     and the read callback is only called with complete individual records."
    [ReadRecordCallback, SocketExceptionHandler]? instance(void write(String record, WriteCallback callback), void close()),
    "The record separator, which may be any nonempty [[String]].
     The default is the newline (`\\n`), so that a record is a line.
     Many internet protocols (e. g. HTTP, STMP, Telnet) use CRLF (`\\r\\n`)."
    String recordSeparator = "\n",
    "The charset that is used to encode and decode records for transfer on the socket."
    Charset charset = utf8,
    "The error strategy for the [[charset]]."
    ErrorStrategy errorStrategy = strict)(void write(ByteBuffer content, WriteCallback callback), void close()) {
    "Record separator must not be empty"
    assert (!recordSeparator.empty);
    value inst = instance {
        void write(String record, WriteCallback callback) {
            write(charset.encodeBuffer(record + recordSeparator), callback);
        }
        close = close;
    };
    if (exists [read, handler] = inst) {
        value currentRecord = StringBuilder();
        variable Integer separatorIndex = 0;
        value decoder = charset.pieceDecoder(errorStrategy);
        "Decode the [[content]] into a [[StringBuilder]]
         and call the [[read]] callback each time a record is complete.

         The record separator is recognized using a naive character matcher.
         No point in bothering with Boyer-Moore, we need to look at every character anyways."
        void readRecord(ByteBuffer content) {
            while (content.hasAvailable) {
                for (char in decoder.more(content.get())) {
                    // compare to the record separator
                    assert (exists separatorChar = recordSeparator[separatorIndex]);
                    if (char == separatorChar) {
                        // all characters up to this one match the separator
                        separatorIndex++;
                        if (separatorIndex == recordSeparator.size) {
                            // this was the entire separator – record done
                            read(currentRecord.string);
                            currentRecord.clear();
                            separatorIndex = 0;
                        }
                    } else {
                        if (separatorIndex > 0) {
                            // append characters we speculatively held back
                            currentRecord.append(recordSeparator.initial(separatorIndex));
                            separatorIndex = 0;
                        }
                        currentRecord.appendCharacter(char);
                    }
                }
            }
        }
        return [readRecord, handler];
    } else {
        return null;
    }
}
