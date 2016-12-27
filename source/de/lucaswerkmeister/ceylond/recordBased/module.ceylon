"""A convenience wrapper around `de.lucaswerkmeister.ceylond.core` for record-based daemons.
   A *record* is considered to be a string, encoded in some fashion (usually UTF-8),
   terminated by a *record separator* (also a string).
   For instance, the record separator might be `"\n"`, in which case a record is a line;
   it might also be `"::"`, in which case the socket message `a::b::c::` is interpreted
   as the three records `a`, `b`, and `c`.

   For example, a simplistic HTTP server could be implemented like this:

   ~~~
   shared void run()
        => startRecordBased {
            recordSeparator = "\r\n";
            function instance(void write(String|ByteBuffer content, WriteCallback callback), void close()) {
                variable String? path = null;
                void read(String record) {
                    if (exists requestedPath = path) {
                        if (record.empty) {
                            String? content;
                            // TODO fill in content based on path (e. g. read file from disc)
                            if (exists content) {
                                write("HTTP/1.0 200 OK", noop);
                                write("Content-type: text/plain; charset=utf-8", noop);
                                write("", noop);
                                write(utf8.encodeBuffer(content), close);
                            } else {
                                write("HTTP/1.0 404 File not found", noop);
                                write("", close);
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
                        // TODO implement other methods if desired
                        else {
                            write("HTTP/1.0 501 Unsupported method ('``method``')", noop);
                            write("", close);
                        }
                    }
                }
                return [read, logAndAbort(`module`)];
            }
            fd = ...;
        };
   ~~~"""
native ("jvm", "js") module de.lucaswerkmeister.ceylond.recordBased "1.0.0" {
    shared import de.lucaswerkmeister.ceylond.core "1.0.0";
}
