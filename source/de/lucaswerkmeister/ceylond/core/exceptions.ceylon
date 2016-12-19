import ceylon.logging {
    ...
}

"An exception that occurs on the server socket."
shared abstract class ServerException(String? description, Throwable? cause)
        of ServerSetupException | SocketSetupException | UnknownServerException
        extends Exception(description, cause) {}

"An exception that occurs during server setup.
 Exceptions of this kind cannot be ignored; the server cannot start."
shared class ServerSetupException(Throwable? cause, String message = "server setup exception")
        extends ServerException(message, cause) {}

"The file descriptor passed to [[start]] is invalid for the current backend."
shared class FileDescriptorInvalidException(String limitation, Integer fd)
        extends ServerSetupException(null, "File descriptor must be ``limitation`` – ``fd`` is not supported") {}

"An exception that occurs during socket setup.
 (This is conceptually more a [[SocketException]] than a [[ServerException]],
 but these errors can occur before the instance function could return a socket exception handler.)"
shared class SocketSetupException(Throwable? cause)
        extends ServerException("socket setup exception", cause) {}

"An unknown server exception."
shared class UnknownServerException(Throwable? cause)
        extends ServerException("unknown server exception", cause) {}

"An exception that occurs on an individual connection socket."
shared abstract class SocketException(String? description, Throwable? cause)
        of SocketClosedException | ReadCallbackException | WriteCallbackException | UnknownSocketException
        extends Exception(description, cause) {}

"The socket is closed, e. g. because the other side closed it or because the connection broke.
 Exceptions of this kind cannot be ignored; the socket is closed.

 Note that on the JVM, it’s not always possible to determine whether an `IOException` means a closed socket;
 some may be misclassified as an [[UnknownSocketException]].
 Unless you can extract more information from the unknown exception than this module can,
 it’s safest to treat the two as equivalent."
shared class SocketClosedException()
        extends SocketException("socket closed", null) {}

"A wrapper for an exception that was thrown from a read callback."
shared class ReadCallbackException(Throwable cause)
        extends SocketException("read callback exception", cause) {}

"A wrapper for an exception that was thrown from a write callback."
shared class WriteCallbackException(Throwable cause)
        extends SocketException("write callback exception", cause) {}

"An unknown exception that occurred during a socket operation.

 It is **strongly recommended** to abort on these exceptions (return [[false]] from the error handler),
 since on the JVM they cannot reliably be distinguished from a [[SocketClosedException]]."
shared class UnknownSocketException(Throwable? cause)
        extends SocketException("unknown socket exception", cause) {}

"A simple default error handler for both server and socket errors.
 It logs the exception on a logger for the given [[category]]
 (level [[ceylon.logging::error]] for [[socket exceptions|SocketException]] and [[ceylon.logging::fatal]] for [[server exceptions|ServerException]])
 and then returns [[false]] to abort the connection or the server.
 
 The [[category]] argument defaults to this module;
 you probably want to use your own module instead, like this:
 
     value handler = logAndAbort(`module`);"
shared ServerExceptionHandler&SocketExceptionHandler logAndAbort(Category category = `module`) {
    value log = logger(category);
    return (ServerException|SocketException exception) {
        switch (exception)
        case (is SocketException) { log.error("socket exception", exception); }
        case (is ServerException) { log.fatal("server exception", exception); }
        return false;
    };
}

"A [[log writer function|LogWriter]] that prints messages to standard error,
 prefixed with the priority in a format that the systemd journal interprets as log level (see `sd-daemon(3)`).
 (The timestamp is not included because that’s the journal’s job.)

 This log writer function must be registered explicitly by calling:

     addLogWriter(writeSystemdLog);"
shared void writeSystemdLog(Priority priority, Category category, String message, Throwable? throwable) {
    String sd_level;
    switch (priority)
    case (trace | debug) { sd_level = "<7>"; } // SD_DEBUG
    case (info) { sd_level = "<6>"; } // SD_INFO
    case (warn) { sd_level = "<4>"; } // SD_WARNING
    case (error) { sd_level = "<3>"; } // SD_ERR
    case (fatal) { sd_level = "<2>"; } // SD_CRIT
    process.writeErrorLine(sd_level + message);
    if (exists throwable) {
        printStackTrace(throwable, (String string) {
                value message = string.trimTrailing("\r\n".contains);
                if (message.empty) { return; }
                for (line in message.lines) {
                    process.writeErrorLine(sd_level + line);
                }
            });
    }
}
