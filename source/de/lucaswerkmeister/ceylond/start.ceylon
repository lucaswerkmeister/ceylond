import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.base {
    base16String
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
    Thread,
    Void
}
import java.io {
    FileDescriptor
}
import java.nio {
    JByteBuffer=ByteBuffer
}
import java.nio.channels {
    AsynchronousChannelGroup,
    AsynchronousCloseException,
    AsynchronousServerSocketChannel,
    AsynchronousSocketChannel,
    CompletionHandler,
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
import java.util.concurrent {
    Executors,
    TimeUnit { seconds=SECONDS }
}
import java.net {
    InetSocketAddress
}

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

native ("jvm") class Connection(Selector selector, SocketChannel socket) {
    Queue<JByteBuffer->WriteCallback> writes = LinkedList<JByteBuffer->WriteCallback>();
    late ReadCallback read;

    shared void doRead() {
        print("doing read");
        value jbuffer = makeReceiveBuffer();
        socket.read(jbuffer);
        jbuffer.flip();
        value cbuffer = bytebuffer_j2c(jbuffer);
        read(cbuffer);
    }
    shared void doWrite() {
        print("doing write");
        if (exists jbuffer->callback = writes.front) {
            print("have something to write");
            socket.write(jbuffer);
            if (jbuffer.remaining() <= 0) {
                print("write was full");
                writes.accept();
                callback();
            }
        }
    }
    shared void write(ByteBuffer content, WriteCallback callback) {
        print("enqueue write job");
        writes.offer(bytebuffer_c2j(content)->callback);
    }
    shared void setReadCallback(ReadCallback read) {
        this.read = read;
    }
}

shared alias ReadCallback => Anything(ByteBuffer);
shared alias WriteCallback => Anything();

native shared void start(ReadCallback? instance(void write(ByteBuffer content, WriteCallback callback), void close()));

native ("jvm") shared void start(ReadCallback? instance(void write(ByteBuffer content, WriteCallback callback), void close())) {

    print("starting");
    value ctr = javaClass<FileDescriptor>().getDeclaredConstructor(intType);
    ctr.setAccessible(ObjectArray(1, ctr), true);
    print("got accessible constructor");
    value fd = ctr.newInstance(JInteger(3));
    print("got fd");
    
    value server = ServerSocketChannel.open();
    print("got server socket channel");

    value address = InetSocketAddress(0);
    value localAddressField = javaClassFromInstance(server).getDeclaredField("localAddress");
    localAddressField.setAccessible(ObjectArray(1, localAddressField), true);
    localAddressField.set(server, address);
    print("bound server socket channel");

    print(javaClassFromInstance(server));
    value openField = javaClass<AbstractInterruptibleChannel>().getDeclaredField("open");
    openField.setAccessible(ObjectArray(1, openField), true);
    openField.set(server, JBoolean(true));
    print("un-closed server socket channel");

    value fdField = javaClassFromInstance(server).getDeclaredField("fd");
    fdField.setAccessible(ObjectArray(1, fdField), true);
    fdField.set(server, fd);
    value fdValField = javaClassFromInstance(server).getDeclaredField("fdVal");
    fdValField.setAccessible(ObjectArray(1, fdValField), true);
    fdValField.set(server, JInteger(3));
    print("injected fd");

    server.configureBlocking(false);
    print("made server non-blocking");

    value selector = Selector.open();
    print("got selector");
    server.register(selector, op_accept);
    print("registered selector");

    object extends Thread() {
        shared actual void run() {
            print("thread started");
            while (true) {
                if (selector.select() > 0) {
                    value selectedKeys = selector.selectedKeys();
                    for (selectedKey in selectedKeys) {
                        if (selectedKey.acceptable) {
                            print("server acceptable");
                            value socket = server.accept();
                            socket.configureBlocking(false);
                            value connection = Connection(selector, socket);
                            socket.register(selector, op_read.or(op_write), connection);
                            value readCallback = instance {
                                write = connection.write;
                                close = socket.close;
                            };
                            if (exists readCallback) {
                                connection.setReadCallback(readCallback);
                            } else {
                                server.close();
                            }
                        } else {
                            assert (is Connection connection = selectedKey.attachment());
                            print("ready to read or write");
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
                    print("done");
                    break;
                }
            }
        }
    }.start();
    print("launched thread");

}

dynamic Socket {
    shared formal void setEncoding(String encoding);
    shared formal void on(String event, void callback(NodeBuffer buffer));
    shared formal void write(String data, String encoding, void callback());
    shared formal void end();
}

dynamic NodeBuffer {
    shared formal String toString(String encoding);
}

native ("js") shared void start(ReadCallback? instance(void write(ByteBuffer content, WriteCallback callback), void close())) {
    print("starting up");
    try {
        Boolean startInstance(Socket socket) {
            print("starting instance");
            socket.setEncoding("hex");
            socket.on {
                event = "error";
                void callback(NodeBuffer error) {
                    print("there was a socket error!");
                    dynamic { console.log(error); }
                }
            };
            print("registered socket error handler");
            value read = instance {
                void write(ByteBuffer content, WriteCallback callback) {
                    String hex = base16String.encode(content);
                    print("write hex: ``hex``");
                    socket.write(hex, "hex", () => callback());
                    print("wrote hex");
                }
                void close() {
                    print("end socket");
                    socket.end();
                }
            };
            if (exists read) {
                print("have an instance");
                socket.on {
                    event = "data";
                    void callback(NodeBuffer buffer) {
                        print("read something");
                        String hex = buffer.toString("hex");
                        print("read hex: ``hex``");
                        read(base16String.decodeBuffer(hex));
                    }
                };
                print("registered read handler");
                return true;
            } else {
                print("don’t have an instance");
                return false;
            }
        }
        print("creating server");
        dynamic {
            dynamic server = net.createServer();
            server.on("connection", (Socket socket) {
                    Boolean keepListening = startInstance(socket);
                    if (!keepListening) {
                        print("close server");
                        server.close();
                    }
                });
            print("registered server connection handler");
            server.on("error", (dynamic error) {
                    print("there was a server error!");
                    console.log(error);
                });
            print("registered server error handler");
            server.listen(dynamic [fd = 3;]);
        }
        print("started without crash");
    } catch (Throwable t) {
        print("there was an outer error");
        t.printStackTrace();
    }
}
