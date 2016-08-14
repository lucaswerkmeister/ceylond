import ceylon.logging {
    Category,
    logger
}

"An exception that occurs on the server socket."
shared abstract class ServerException(String? description, Throwable? cause)
        of ServerSetupException | SocketSetupException | UnknownServerException
        extends Exception(description, cause) {}

"An exception that occurs during server setup.
 Exceptions of this kind cannot be ignored; the server cannot start."
shared class ServerSetupException(Throwable? cause)
        extends ServerException("server setup exception", cause) {}

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

"The socket is closed, e. g. because the other side closed it or because the connection broke."
shared class SocketClosedException()
        extends SocketException("socket closed", null) {}

"A wrapper for an exception that was thrown from a read callback."
shared class ReadCallbackException(Throwable cause)
        extends SocketException("read callback exception", cause) {}

"A wrapper for an exception that was thrown from a write callback."
shared class WriteCallbackException(Throwable cause)
        extends SocketException("write callback exception", cause) {}

"An unknown socket exception."
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
