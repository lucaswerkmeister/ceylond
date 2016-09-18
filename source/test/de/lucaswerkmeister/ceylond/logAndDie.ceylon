import de.lucaswerkmeister.ceylond {
    ServerException,
    ServerExceptionHandler,
    SocketException,
    SocketExceptionHandler
}
import ceylon.logging {
    Category,
    logger
}

suppressWarnings ("expressionTypeNothing")
ServerExceptionHandler&SocketExceptionHandler logAndDie(Category category = `module`) {
    value log = logger(category);
    return (ServerException|SocketException exception) {
        switch (exception)
        case (is SocketException) { log.error("socket exception", exception); }
        case (is ServerException) { log.fatal("server exception", exception); }
        process.exit(1);
        return false;
    };
}
