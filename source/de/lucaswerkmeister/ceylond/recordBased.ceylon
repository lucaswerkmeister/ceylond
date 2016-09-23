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
see (`function startRecordBased`)
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
        "The partial record currently being read."
        value currentRecord = StringBuilder();
        "The current index into the separator.
         The algorithmic invariant is that `recordSeparator.initial(separatorIndex)` has been read,
         but not yet added to the [[current record|currentRecord]].
         The record separator thus also serves as a “buffer” of characters
         that may yet have to be added to the current record
         if the next character doesn’t match the record separator."
        variable Integer separatorIndex = 0;
        value decoder = charset.pieceDecoder(errorStrategy);
        "Decode the [[content]] into a [[StringBuilder]]
         and call the [[read]] callback each time a record is complete."
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
                        // mismatch. now it gets complicated…
                        if (separatorIndex > 0) {
                            // the record separator may start somewhere else within those characters we speculatively held back
                            for (startIndex in 1:separatorIndex) {
                                "Sanity check so assumption for [[readFragment]] holds.
                                 Should be guaranteed by loop measure."
                                assert (0 < startIndex <= separatorIndex);
                                "The size of the separator fragment we’re currently comparing.
                                 In the last iteration, this will be one, comparing just [[char]]."
                                value fragmentSize = separatorIndex - startIndex + 1;
                                "The characters we actually read from the socket.
                                 (We can get all of them except the last one from the record separator
                                 because we know that up to [[separatorIndex]] they are identical to the record separator,
                                 and the loop only runs up to [[separatorIndex]].)"
                                value readFragment = recordSeparator[startIndex:(fragmentSize-1)] + char.string;
                                "The characters from the record separator we are comparing against."
                                value recordFragment = recordSeparator.initial(fragmentSize);
                                "Sanity check"
                                assert (readFragment.size == recordFragment.size,
                                    readFragment.size == fragmentSize);
                                if (readFragment == recordFragment) {
                                    // append characters that didn’t match (up to readFragment)
                                    currentRecord.append(recordSeparator.initial(startIndex));
                                    // continue comparing past the matching part (recordSeparator.size)
                                    separatorIndex = fragmentSize;
                                    break;
                                }
                            } else {
                                // no match at all, append all held-back characters
                                currentRecord.append(recordSeparator.initial(separatorIndex));
                                currentRecord.appendCharacter(char);
                                separatorIndex = 0;
                            }
                        } else {
                            // There’s no dangling matching part, append the character and be done with it.
                            // (separatorIndex is already 0 and stays there.)
                            // (This is the common case, by the way.)
                            currentRecord.appendCharacter(char);
                        }
                    }
                }
            }
        }
        return [readRecord, handler];
    } else {
        return null;
    }
}

"""Start listening on the socket, reading and writing records.

   Usage example:

       startRecordBased {
           function instance(void write(String record, WriteCallback callback), void close()) {
               write("Hello, World! Please supply your name.", noop);
               void read(String name) {
                   write("Greetings, ``name``!", noop);
                   write("Goodbye.", close);
               }
               return [read, logAndAbort(`module`)];
           }
           fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
       };"""
see (`function start`, `function makeRecordBasedInstance`)
aliased ("startLineBased")
shared void startRecordBased(
    "See [[makeRecordBasedInstance.instance]]."
    [ReadRecordCallback, SocketExceptionHandler]? instance(void write(String record, WriteCallback callback), void close()),
    "See [[start.fd]]."
    Integer fd,
    "See [[start.handler]]."
    ServerExceptionHandler handler = logAndAbort(),
    "See [[start.concurrent]]."
    Boolean concurrent = true,
    "See [[makeRecordBasedInstance.recordSeparator]]."
    String recordSeparator = "\n",
    "See [[makeRecordBasedInstance.charset]]."
    Charset charset = utf8,
    "See [[makeRecordBasedInstance.errorStrategy]]."
    ErrorStrategy errorStrategy = strict)
        => start {
            instance = makeRecordBasedInstance {
                instance = instance;
                recordSeparator = recordSeparator;
                charset = charset;
            };
            fd = fd;
            handler = handler;
            concurrent = concurrent;
        };
