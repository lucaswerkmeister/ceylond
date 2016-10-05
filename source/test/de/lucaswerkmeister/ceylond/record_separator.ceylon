import de.lucaswerkmeister.ceylond.core {
    SocketClosedException,
    SocketException,
    WriteCallback
}
import de.lucaswerkmeister.ceylond.recordBased {
    startRecordBased
}
import ceylon.logging {
    logger
}

"""Expects the first line of the following text:
   
       ababbaabbcdabababbaabaababbaababbaababbaabbefababbaabaghababbaaba
       ababbaabA  ababBaaba  ababbaaba   ababbaabA  ababbaaba  ababbaaba
                    ababbaaba      ababbaaba
   
   Which should, with the record separator `ababbaaba` (as indicated on the second and third line),
   register as the following records:
   
   1. `ababbaabbcdab`
   2. `` (empty string)
   3. `bbaababbaabbef`
   4. `gh`"""
shared void record_separator()
        => startRecordBased {
            function instance(void write(String record, WriteCallback callback), void close()) {
                value log = logger(`module`);
                variable [String*] expected = ["ababbaabbcdab", "", "bbaababbaabbef", "gh"];
                void read(String record) {
                    assert (nonempty [first, *rest] = expected);
                    log.trace("expecting ‘``first``’,
                                  got       ‘``record``’");
                    assert (record == first);
                    expected = rest;
                }
                Boolean expectCloseWhenDone(SocketException e) {
                    if (e is SocketClosedException && expected.empty) {
                        log.info("socket closed at end of expected sequence, exit successfully");
                        process.exit(0);
                        return true;
                    } else {
                        log.error("unexpected error, exit failure", e);
                        process.exit(1);
                        return false;
                    }
                }
                return [read, expectCloseWhenDone];
            }
            recordSeparator = "ababbaaba";
            fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
        };
