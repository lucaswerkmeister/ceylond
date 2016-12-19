import de.lucaswerkmeister.ceylond.core {
    WriteCallback
}
import de.lucaswerkmeister.ceylond.recordBased {
    startRecordBased
}
import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}

shared void http_server()
        => startRecordBased {
            function instance(void write(String|ByteBuffer content, WriteCallback callback), void close()) {
                variable String? path = null;
                void read(String record) {
                    if (exists requestedPath = path) {
                        if (record.empty) {
                            String? content;
                            switch (requestedPath)
                            case ("/info") {
                                content = "`` `module`.name ``/`` `module`.version `` on Ceylon ``language.version`` “``language.versionName``”";
                            }
                            case ("/greeting") {
                                content = "Hello, World!";
                            }
                            else {
                                content = null;
                                write("HTTP/1.0 404 File not found", noop);
                                write("", close);
                            }
                            if (exists content) {
                                write("HTTP/1.0 200 OK", noop);
                                write("Content-type: text/plain; charset=utf-8", noop);
                                write("", noop);
                                write(utf8.encodeBuffer(content), close);
                            }
                        } else {
                            assert (record.split().first.endsWith(":"));
                            // ignore header
                        }
                    } else {
                        value parts = record.split().sequence();
                        assert (exists method = parts[0]);
                        switch (method)
                        case ("GET") {
                            assert (exists p = parts[1],
                                exists version = parts[2],
                                !parts[3] exists);
                            assert (version in { "HTTP/1.0", "HTTP/1.1" });
                            path = p;
                        }
                        case ("QUIT") {
                            process.exit(if (exists s = parts[1], exists status = parseInteger(s)) then status else 0);
                        }
                        else {
                            write("HTTP/1.0 501 Unsupported method ('``method``')", noop);
                            write("", close);
                        }
                    }
                }
                return [read, logAndDie(`module`)];
            }
            recordSeparator = "\r\n";
            fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
        };
