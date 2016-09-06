import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.base {
    base16String
}
import ceylon.logging {
    Logger,
    logger
}
import ceylon.collection {
    LinkedList,
    Queue
}
import ceylon.interop.java {
    javaClass,
    javaClassFromInstance
}
import java.lang {
    JBoolean=Boolean,
    JInteger=Integer {
        intType=TYPE
    },
    ObjectArray,
    System { inheritedChannel },
    Thread
}
import java.io {
    FileDescriptor
}
import java.nio {
    JByteBuffer=ByteBuffer
}
import java.nio.channels {
    Selector,
    SelectionKey {
        op_accept=OP_ACCEPT,
        op_read=OP_READ,
        op_write=OP_WRITE
    },
    ServerSocketChannel,
    SocketChannel
}
import java.nio.channels.spi {
    AbstractInterruptibleChannel
}
import java.net {
    InetSocketAddress
}

Logger log = logger(`module`);

native ("jvm") JByteBuffer bytebuffer_c2j(ByteBuffer cbuffer) {
    value jbuffer = JByteBuffer.allocate(cbuffer.available);
    while (cbuffer.hasAvailable) {
        jbuffer.put(cbuffer.get());
    }
    cbuffer.flip();
    jbuffer.flip();
    return jbuffer;
}
native ("jvm") ByteBuffer bytebuffer_j2c(JByteBuffer jbuffer) {
    value cbuffer = ByteBuffer.ofSize(jbuffer.remaining());
    while (jbuffer.hasRemaining()) {
        cbuffer.put(jbuffer.get());
    }
    jbuffer.flip();
    cbuffer.flip();
    return cbuffer;
}
native ("jvm") JByteBuffer makeReceiveBuffer() {
    return JByteBuffer.allocate(4096); // TODO what’s a good capacity?
}

"A handler for a single connection.
 After instantiating it, register the [[selector]] on the [[socket]] with this as the attachment."
native ("jvm") class Connection(Selector selector, SocketChannel socket) {
    "Queue of pending write jobs.
     The position of the byte buffer determines how much of the write is still left to do."
    Queue<JByteBuffer->WriteCallback> writes = LinkedList<JByteBuffer->WriteCallback>();
    late ReadCallback read;
    late SocketExceptionHandler handler;

    "Read data from the socket and pass it to the [[read]] callback.
     Call this method when the socket has been signalled to be ready for reading."
    shared void doRead() {
        log.trace("doing read");
        value jbuffer = makeReceiveBuffer();
        socket.read(jbuffer);
        jbuffer.flip();
        value cbuffer = bytebuffer_j2c(jbuffer);
        try {
            read(cbuffer);
        } catch (Throwable t) {
            handler(ReadCallbackException(t));
            // TODO handler return value
        }
    }
    "Take a queued write (if there is one) and write it to the socket.
     Call this method when the socket has been signalled to be ready for writing."
    shared void doWrite() {
        log.trace("doing write");
        if (exists jbuffer->callback = writes.front) {
            log.trace("have something to write");
            socket.write(jbuffer);
            if (jbuffer.remaining() <= 0) {
                log.trace("write was full");
                writes.accept();
                try {
                    callback();
                } catch (Throwable t) {
                    handler(WriteCallbackException(t));
                    // TODO handler return value
                }
            }
        }
    }
    "Enqueue a write job.
     The [[content]] will be written as soon as the socket is ready for writing
     and all prior read jobs are completed,
     and the [[callback]] will be called once the write is complete."
    shared void write(ByteBuffer content, WriteCallback callback) {
        log.trace("enqueue write job");
        writes.offer(bytebuffer_c2j(content)->callback);
    }
    shared void setReadCallback(ReadCallback read) {
        this.read = read;
    }
    shared void setHandler(SocketExceptionHandler handler) {
        this.handler = handler;
    }
}

"Make a [[ServerSocketChannel]] for the specified file descriptor using JVM implementation-specific reflection hackery.
 
 The current implementation works on OpenJDK, but probably not on Oracle JDK.
 If there’s enough demand, an Oracle version might be added in the future.
 The same goes for other JVM implementations."
native ("jvm") ServerSocketChannel makeChannel(Integer fd) {
    log.trace("making server socket channel");
    value fileDescriptorConstructor = javaClass<FileDescriptor>().getDeclaredConstructor(intType);
    fileDescriptorConstructor.setAccessible(ObjectArray(1, fileDescriptorConstructor), true);
    log.trace("got accessible constructor");
    value fileDescriptor = fileDescriptorConstructor.newInstance(JInteger(fd));
    log.trace("got fileDescriptor");
    
    value server = ServerSocketChannel.open();
    log.trace("got server socket channel");
    
    value address = InetSocketAddress(0);
    value localAddressField = javaClassFromInstance(server).getDeclaredField("localAddress");
    localAddressField.setAccessible(ObjectArray(1, localAddressField), true);
    localAddressField.set(server, address);
    log.trace("bound server socket channel");
    
    value openField = javaClass<AbstractInterruptibleChannel>().getDeclaredField("open");
    openField.setAccessible(ObjectArray(1, openField), true);
    openField.set(server, JBoolean(true));
    log.trace("un-closed server socket channel");
    
    value fdField = javaClassFromInstance(server).getDeclaredField("fd");
    fdField.setAccessible(ObjectArray(1, fdField), true);
    fdField.set(server, fileDescriptor);
    value fdValField = javaClassFromInstance(server).getDeclaredField("fdVal");
    fdValField.setAccessible(ObjectArray(1, fdValField), true);
    fdValField.set(server, JInteger(fd));
    log.trace("injected fd");
    
    return server;
}

"A read callback, to be called with a ready-to-read [[ByteBuffer]] when data has been read from the socket."
shared alias ReadCallback => Anything(ByteBuffer);
"A write callback, to be called once a write is fully completed.
 (There is no count of bytes written;
 this library (on JS: Node itself) takes care of repeating writes until they’re completely done.)"
shared alias WriteCallback => Anything();

"A handler for server exceptions.
 The return value determines whether the server proceeds or not;
 [[true]] means to continue running and accepting connections if possible,
 [[false]] means to stop the server.
 If the server cannot continue even though the handler requests it,
 a warning is logged."
shared alias ServerExceptionHandler => Boolean(ServerException);
"A handler for socket exceptions.
 The return value determines whether the socket proceeds or not;
 [[true]] means to continue reading and writing on this socket,
 [[false]] means to close it.
 If the socket cannot continue even though the handler requests it,
 a warning is logged."
shared alias SocketExceptionHandler => Boolean(SocketException);

"Start listening on the socket.
 
 **VERY IMPORTANT NOTE:** You **must** return from the main program (`run`) after calling this function;
 on Node.js, the socket will not receive any data until control flow has returned to the main event loop.
 (On the JVM, the socket is handled in a separate thread, but you should return from the main program nonetheless.)
 You may call [[start]] multiple times with different [[file descriptors|fd]] to listen on multiple sockets,
 and you may also log messages or do other stuff after calling [[start]],
 but you must not enter any long-running activities or even an infinite loop,
 otherwise the sockets won’t work."
native shared void start(
    "This function is called whenever a new connection to the socket is opened;
     it receives a function that can be used to write to the socket, and a function to close it.
     It returns two functions, one that is called whenever there is new data on the socket
     and one that handles exceptions on this socket,
     or [[null]] to signal that the socket should stop listening."
    see (`alias SocketExceptionHandler`)
    [ReadCallback, SocketExceptionHandler]? instance(void write(ByteBuffer content, WriteCallback callback), void close()),
    "The file descriptor to listen on.
     
     For inetd and derivatives (e. g. xinetd), this should be 0.
     systemd by default assigns the first socket to file descriptor 3,
     but also supports multiple sockets, which it assigns to subsequent file descriptors (4, 5, …).
     
     The JVM only supports file descriptor 0 natively;
     if another file descriptor is specified,
     a channel object for it is obtained via reflection,
     in a manner that probably only works on OpenJDK.
     
     Node.js allows listening on any file descriptor natively,
     *except* file descriptor 0, where it fails with inexplicable errors without any useful stack trace.
     
     Thus, the choice of file descriptor to listen on depends on several factors:
     
     - If your program uses multiple sockets,
       use file descriptors 3 & seq.,
       and accept that the program might not run on some JVM implementations.
     - If your program only needs to run on the JVM, use file descriptor 0,
       and add `StandardInput=socket` to your systemd service file.
     - If your program only needs to run on JS, use file descriptor 3.
     - If your program needs to run on both backends,
       and you don’t want to make the choice of file descriptor backend-specific,
       use file descriptor 3,
       and accept that the program might not run on some JVM implementations."
    Integer fd,
    see (`alias ServerExceptionHandler`)
    ServerExceptionHandler handler = logAndAbort(),
    "Whether to allow concurrent connections or not.
     
     If [[true]], every connection is accepted as soon as possible.
     If [[false]], a new connection is only accepted once the previous one has terminated;
     this is useful if your program changes some global state,
     and multiple instances running concurrently may disturb each other."
    Boolean concurrent = true);

native ("jvm") shared void start([ReadCallback, SocketExceptionHandler]? instance(void write(ByteBuffer content, WriteCallback callback), void close()), Integer fd, ServerExceptionHandler handler = logAndAbort(), Boolean concurrent = true) {
    try {
        ServerSocketChannel server;
        if (fd == 0) {
            assert (is ServerSocketChannel ic = inheritedChannel());
            server = ic;
            log.trace("got inherited channel");
        } else if (fd >= 3) {
            server = makeChannel(fd);
        } else {
            throw FileDescriptorInvalidException("0 or >= 3", fd);
        }

        server.configureBlocking(false);
        log.trace("made server non-blocking");

        value selector = Selector.open();
        log.trace("got selector");
        server.register(selector, op_accept);
        log.trace("registered selector");

        object extends Thread() {
            shared actual void run() {
                log.trace("thread started");
                while (true) {
                    // TODO concurrent; error handling (what if the other side closes the socket?)
                    if (selector.select() > 0) {
                        value selectedKeys = selector.selectedKeys();
                        for (selectedKey in selectedKeys) {
                            if (selectedKey.acceptable) {
                                log.trace("server acceptable");
                                value socket = server.accept();
                                socket.configureBlocking(false);
                                value connection = Connection(selector, socket);
                                socket.register(selector, op_read.or(op_write), connection);
                                value inst = instance {
                                    write = connection.write;
                                    close = socket.close;
                                };
                                if (exists [read, error] = inst) {
                                    connection.setReadCallback(read);
                                    connection.setHandler(error);
                                } else {
                                    server.close();
                                }
                            } else {
                                assert (is Connection connection = selectedKey.attachment());
                                log.trace("ready to read or write");
                                if (selectedKey.readable) {
                                    connection.doRead();
                                }
                                if (selectedKey.writable) {
                                    connection.doWrite();
                                }
                            }
                        }
                        selectedKeys.clear();
                    } else {
                        log.trace("done");
                        break;
                    }
                }
            }
        }.start();
        log.trace("launched thread");
    } catch (Throwable t) {
        ServerException se;
        if (is ServerException t) { se = t; }
        else { se = UnknownServerException(t); }
        if (handler(se)) {
            log.warn("server exception handler requests continue but server cannot continue");
        }
    }
}

dynamic Socket {
    shared formal void setEncoding(String encoding);
    shared formal void on(String event, Anything(Nothing) callback);
    shared formal void write(String data, String encoding, void callback());
    shared formal void end();
}

dynamic NodeBuffer {
    shared formal String toString(String encoding);
}

native ("js") shared void start([ReadCallback, SocketExceptionHandler]? instance(void write(ByteBuffer content, WriteCallback callback), void close()), Integer fd, ServerExceptionHandler handler = logAndAbort(), Boolean concurrent = true) {
    // TODO concurrent
    log.trace("starting up");
    try {
        if (fd < 3) {
            throw FileDescriptorInvalidException(">= 3", fd);
        }
        Boolean startInstance(Socket socket) {
            log.trace("starting instance");
            socket.setEncoding("hex");
            variable SocketExceptionHandler? handler = null;
            value inst = instance {
                void write(ByteBuffer content, WriteCallback callback) {
                    String hex = base16String.encode(content);
                    log.trace("write hex");
                    socket.write(hex, "hex", () {
                            try {
                                callback();
                            } catch (Throwable t) {
                                assert (exists h = handler);
                                value proceed = h(WriteCallbackException(t));
                                if (!proceed) {
                                    socket.end();
                                }
                            }
                        });
                    log.trace("wrote hex");
                }
                void close() {
                    log.trace("end socket");
                    socket.end();
                }
            };
            if (exists [read, error] = inst) {
                log.trace("have an instance");
                handler = error;
                socket.on("data", (NodeBuffer buffer) {
                        log.trace("read something");
                        String hex = buffer.toString("hex");
                        value cbuffer = base16String.decodeBuffer(hex);
                        try {
                            read(cbuffer);
                        } catch (Throwable t) {
                            value proceed = error(ReadCallbackException(t));
                            if (!proceed) {
                                socket.end();
                            }
                        }
                    });
                log.trace("registered read handler");
                socket.on("error", (Throwable e) {
                        SocketException exc;
                        if (e.message == "write EPIPE") {
                            exc = SocketClosedException();
                        } else {
                            exc = UnknownSocketException(e);
                        }
                        value proceed = error(exc);
                        if (!proceed) {
                            socket.end();
                        }
                    });
                log.trace("registered socket error handler");
                return true;
            } else {
                log.trace("don’t have an instance");
                return false;
            }
        }
        log.trace("creating server");
        dynamic {
            dynamic server = net.createServer();
            server.on("connection", (Socket socket) {
                    try {
                        Boolean keepListening = startInstance(socket);
                        if (!keepListening) {
                            log.trace("close server");
                            server.close();
                        }
                    } catch (Throwable t) {
                        value proceed = handler(SocketSetupException(t));
                        if (!proceed) {
                            server.close();
                        }
                    }
                });
            log.trace("registered server connection handler");
            server.on("error", (dynamic error) {
                    value proceed = handler(UnknownServerException(error));
                    if (!proceed) {
                        server.close();
                    }
                });
            log.trace("registered server error handler");
            server.listen(dynamic [fd = fd;]);
        }
        log.trace("started without crash");
    } catch (Throwable t) {
        ServerException se;
        if (is ServerException t) { se = t; }
        else { se = UnknownServerException(t); }
        if (handler(se)) {
            log.warn("server exception handler requests continue but server cannot continue");
        }
    }
}
