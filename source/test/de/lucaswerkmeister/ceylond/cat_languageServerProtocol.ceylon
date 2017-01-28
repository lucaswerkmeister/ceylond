import ceylon.json {
    JsonObject,
    Value
}
import ceylon.logging { ... }
import de.lucaswerkmeister.ceylond.core {
    WriteCallback,
    writeSystemdLog
}
import de.lucaswerkmeister.ceylond.languageServerProtocol {
    startLanguageServer
}

shared void cat_languageServerProtocol() {
    defaultPriority = trace;
    addLogWriter(writeSystemdLog);
    startLanguageServer {
        function instance(void write(Value content, WriteCallback callback), void close()) {
            void read(Value content) {
                write(JsonObject {
                    "message"->"Congratulations!",
                    "original"->content
                }, closeAndExit(close));
            }
            return [read, logAndDie(`module`)];
        }
        fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
    };
}
