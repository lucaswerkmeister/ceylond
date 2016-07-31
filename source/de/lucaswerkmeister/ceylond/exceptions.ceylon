import ceylon.logging {
    Category,
    logger
}

"An exception that occurs on the server socket."
shared abstract class ServerException(String? description, Throwable? cause)
        of ServerSetupException | UnknownServerException
        extends Exception(description, cause) {}

"An exception that occurs during server setup.
 Exceptions of this kind cannot be ignored; the server cannot start."
shared class ServerSetupException(String? description, Throwable? cause)
        extends ServerException(description, cause) {}

"An unknown server exception."
shared class UnknownServerException(String? description, Throwable? cause)
        extends ServerException(description, cause) {}

"An exception that occurs on an individual connection socket."
shared abstract class SocketException(String? description, Throwable? cause)
        of SocketSetupException | SocketClosedException | ReadCallbackException | WriteCallbackException | UnknownSocketException
        extends Exception(description, cause) {}

"An exception that occurs during socket setup.
 Exceptions of this kind cannot be ignored; this connection fails."
shared class SocketSetupException(String? description, Throwable? cause)
        extends SocketException(description, cause) {}

"The socket is closed, e. g. because the other side closed it or because the connection broke."
shared class SocketClosedException(String? description, Throwable? cause)
        extends SocketException(description, cause) {}

"A wrapper for an exception that was thrown from a read callback."
shared class ReadCallbackException(Throwable cause)
        extends SocketException("read callback exception", cause) {}

"A wrapper for an exception that was thrown from a write callback."
shared class WriteCallbackException(Throwable cause)
        extends SocketException("write callback exception", cause) {}

"An unknown socket exception."
shared class UnknownSocketException(String? description, Throwable? cause)
        extends SocketException(description, cause) {}

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
