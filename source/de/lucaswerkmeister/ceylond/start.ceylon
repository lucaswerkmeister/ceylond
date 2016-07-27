import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.base {
    base16String
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
    CompletionHandler
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
native ("jvm") ByteBuffer bytebuffer_j2c(JByteBuffer jbuffer, Integer count) {
    value cbuffer = ByteBuffer.ofSize(count);
    for (i in 0:count) {
        cbuffer.put(jbuffer.get());
    }
    jbuffer.flip();
    cbuffer.flip();
    return cbuffer;
}
native ("jvm") JByteBuffer makeReceiveBuffer() {
    return JByteBuffer.allocate(4096); // TODO what’s a good capacity?
}

shared alias ReadCallback => Anything(ByteBuffer);
shared alias WriteCallback => Anything(Integer);

native shared void start(ReadCallback? instance(void write(ByteBuffer content, WriteCallback callback), void close()));

native ("jvm") shared void start(ReadCallback? instance(void write(ByteBuffer content, WriteCallback callback), void close())) {

    print("starting");
    value ctr = javaClass<FileDescriptor>().getDeclaredConstructor(intType);
    ctr.setAccessible(ObjectArray(1, ctr), true);
    print("got accessible constructor");
    value fd = ctr.newInstance(JInteger(3));
    print("got fd");

    value group = AsynchronousChannelGroup.withThreadPool(Executors.newFixedThreadPool(2)); // single thread won’t work because we need to accept and call read handler concurrently
    value channel = AsynchronousServerSocketChannel.open(group);
    channel.bind(InetSocketAddress(0), 1);
    channel.close();
    print("got socket");

    value openField = javaClassFromInstance(channel).superclass.getDeclaredField("open");
    openField.setAccessible(ObjectArray(1, openField), true);
    openField.set(channel, JBoolean(true));
    print("un-closed socket");

    value fdField = javaClassFromInstance(channel).superclass.getDeclaredField("fd");
    fdField.setAccessible(ObjectArray(1, fdField), true);
    fdField.set(channel, fd);
    print("injected fd");

    channel.accept(null, object satisfies CompletionHandler<AsynchronousSocketChannel, Void> {
            shared actual void completed(AsynchronousSocketChannel result, Void attachment) {
                print("got connection");
                value read = instance {
                    void write(ByteBuffer content, WriteCallback callback) {
                        print("writing");
                        result.write(bytebuffer_c2j(content), null, object satisfies CompletionHandler<JInteger, Void> {
                                shared actual void completed(JInteger bytesWritten, Void attachment) {
                                    print("wrote ``bytesWritten.intValue()`` bytes");
                                    callback(bytesWritten.intValue());
                                }
                                shared actual void failed(Throwable exc, Void attachment) {
                                    exc.printStackTrace();
                                }
                            });
                    }
                    void close() {
                        print("closing");
                        result.close();
                    }
                };
                if (exists read) {
                    variable JByteBuffer buffer = makeReceiveBuffer();
                    result.read(buffer, null, object satisfies CompletionHandler<JInteger, Void> {
                            shared actual void completed(JInteger bytesRead_j, Void attachment) {
                                value bytesRead = bytesRead_j.intValue();
                                if (bytesRead >= 0) {
                                    print("read ``bytesRead`` bytes");
                                    value current = buffer;
                                    current.flip();
                                    buffer = makeReceiveBuffer();
                                    result.read(buffer, null, this);
                                    read(bytebuffer_j2c(current, bytesRead));
                                } else {
                                    print("eof");
                                }
                            }
                            shared actual void failed (Throwable exc, Void attachment) {
                                if (exc is AsynchronousCloseException) {
                                    // ignore
                                    print("read failed due to close");
                                } else {
                                    print("read failed for some other reason:");
                                    exc.printStackTrace();
                                }
                            }
                        });
                    print("registered read completion handler");
                    channel.accept(null, this); // get ready to accept next connection
                    print("re-registered socket completion handler on server");
                }
            }
            shared actual void failed(Throwable exc, Void attachment) {
                exc.printStackTrace();
            }
        });
    print("called accept");
    group.awaitTermination(runtime.maxIntegerValue, seconds);
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
                    value length = content.available;
                    String hex = base16String.encode(content);
                    print("write hex: ``hex``");
                    socket.write(hex, "hex", () => callback(length)); // Node buffers in userspace to ensure every write is complete
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
