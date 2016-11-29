import de.lucaswerkmeister.ceylond.core {
    ReadCallback,
    ServerException,
    SocketExceptionHandler,
    SocketSetupException,
    WriteCallback,
    logAndAbort,
    start
}
import de.lucaswerkmeister.ceylond.packetBased {
    makePacketBasedInstance,
    writeInteger
}
import ceylon.collection {
    ArrayList,
    MutableList
}
import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}

ByteBuffer intToBuffer(Integer int, Integer size) {
    value buffer = ByteBuffer.ofSize(size);
    writeInteger(int, size, buffer);
    buffer.flip();
    return buffer;
}

/*
   Do we want to put a configurable limit on standard input to avoid excessive allocation?
   I suppose yes, and we also want to propagate the max packet size from packetBased to a configurable parameter of daemonize.
 */

class ProcessExit(shared Integer exitCode) extends Exception("process.exit(``exitCode``)`") {}

"Create an instance for [[start]] that runs a given program as daemon.

 The socket protocol is [[packet-based|makePacketBasedInstance]],
 with configurable [[lengthSize]] and [[typeSize]].
 Each connection understands the following packet types:

 - `#00` (0): launch the program.
   This must be the last packet;
   any other packets after this one are an error.
 - `#01` (1): add an argument.
   The packet content is a single, UTF-8 encoded argument.
   Upon launch, all received arguments are sent to [[argumentsMap]]
   (together with the working directory, if one was received – see below),
   and the result (by default, the arguments themselves)
   is made available to the program in [[process.arguments]].
   The mapping function may, for example, turn relative file paths in the arguments into absolute ones,
   since the real working directory of the process is still the daemon working directory and cannot be changed.
 - `#02` (2): set working directory.
   The working directory, if set, will be passed to [[argumentsMap]] along with all arguments
   (otherwise, that argument will be [[null]]).
   This packet may only be sent at most once.
 - `#03` (3): add standard input.
   The packet content is added to a buffer which, upon launch,
   is made available to the process as standard input via [[process.readLine]] and similar functions.
   No encoding is specified;
   language module functions producing text instead of bytes are themselves responsible for decoding the content,
   just as with regular standard input.
   (It is recommended to transfer text in UTF-8 encoding and ensure that the daemon process runs in a UTF-8 locale.)
   Note that the JS backend does not support reading from standard input,
   and this module does nothing to change that.

 Once launched, the program runs to completion.
 Afterwards, the following packet types may be sent:

 - `#80` (128): program exited normally.
   The content is an 8-byte integer in network byte order,
   indicating the exit code ([[process.exit]]’s argument),
   or `0` if the [[run]] function returned normally,
   or `1` if the [[run]] function threw an exception.
   A packet of this type is always sent on termination,
   and it is always the last packet;
   the socket is closed once this packet has been sent.
 - `#81` (129): standard output.
   All standard output produced by the program via [[process.writeLine]] and similar functions
   is stored in a buffer and finally sent in a packet of this type.
   Boundaries between writes are not preserved.
 - `#82` (130): standard error.
   Analogous to standard output (`#81`, see above).
 - `#83` (131): exception stacktrace.
   If the program threw an exception,
   a packet of this type is sent,
   containing the UTF-8 encoded stack trace."
shared [ReadCallback, SocketExceptionHandler]? makeDaemonizeProgramInstance(
    "The program being daemonized."
    void run(),
    "A mapping function that is applied to the arguments
     before they are stored in [[process.arguments]].
     If a working directory packet has been sent,
     that is set as the second argument.
     This function can, for example,
     change relative paths in the arguments to absolute ones
     (relative to the passed working directory)
     to ensure they are valid in the program
     when it runs under the daemon’s working directory."
    String[] argumentsMap(String[] arguments, String? workingDirectory) => arguments,
    "The size of the packet length.
     By default, a conservative size of 2 is chosen,
     but I/O heavy programs may require larger sizes
     (all output is sent in a single packet)."
    Integer lengthsize = 2,
    "The size of the type length.
     The default of 1 is sufficient for all understood types,
     but a higher value may be desirable for alignment purpose."
    Integer typeSize = 1)(void write(ByteBuffer content, WriteCallback callback), void close()) {
    return makePacketBasedInstance {
        function instance(void write(ByteBuffer content, Integer type, WriteCallback callback), void close()) {
            MutableList<String> arguments = ArrayList<String>();
            variable String? workingDirectory = null;
            ByteBuffer standardInput = ByteBuffer.ofSize(0);
            ByteBuffer standardOutput = ByteBuffer.ofSize(0);
            ByteBuffer standardError = ByteBuffer.ofSize(0);
            variable Boolean launched = false;
            void readArgument(ByteBuffer content) {
                "Program must not be launched yet"
                assert (!launched);
                arguments.add(utf8.decode(content));
            }
            void readWorkingDirectory(ByteBuffer content) {
                "Working directory can only be set once"
                assert (!workingDirectory exists);
                "Program must not be launched yet"
                assert (!launched);
                workingDirectory = utf8.decode(content);
            }
            void readStandardInput(ByteBuffer content) {
                "Program must not be launched yet"
                assert (!launched);
                grow(standardInput, content.available);
                while (content.hasAvailable) {
                    standardInput.put(content.get());
                }
            }
            void launch(ByteBuffer content) {
                "Launch packet must be empty"
                assert (!content.hasAvailable);
                "Program can only be launched once"
                assert (!launched);
                launched = true;
                variable value args = arguments.sequence();
                if (exists wd = workingDirectory) {
                    args = argumentsMap(args, wd);
                }
                setProcessArguments(args);
                trapProcessExit {
                    void trap(Integer exitCode) {
                        throw ProcessExit(exitCode);
                    }
                };
                setStandardInput(standardInput);
                setStandardOutput(standardOutput);
                setStandardError(standardError);
                void writeStreams() {
                    standardOutput.flip();
                    write(standardOutput, #81, noop);
                    standardError.flip();
                    write(standardError, #82, noop);
                }
                try {
                    run();
                    writeStreams();
                    write(intToBuffer(0, 8), #80, close);
                } catch (ProcessExit pe) {
                    writeStreams();
                    write(intToBuffer(pe.exitCode, 8), #80, close);
                } catch (Throwable t) {
                    writeStreams();
                    StringBuilder stackTrace = StringBuilder();
                    printStackTrace(t, stackTrace.append);
                    write(utf8.encodeBuffer(stackTrace), #83, noop);
                    write(intToBuffer(1, 8), #80, close);
                }
            }

            value typeMap = map {
                #00->launch,
                #01->readArgument,
                #02->readWorkingDirectory,
                #03->readStandardInput
            };
            return [typeMap, logAndAbort(`module`)];
        }
        lengthSize = 2;
        typeSize = 1;
    }(write, close);
}

shared void daemonizeProgram(void run(), Integer fd, String[] argumentsMap(String[] arguments, String workingDirectory) => arguments)
        => start {
            instance = makeDaemonizeProgramInstance(run);
            fd = fd;
            Boolean handler(ServerException exception) {
                if (is SocketSetupException exception) {
                    log.error("error setting up socket", exception);
                    return true;
                } else {
                    return false;
                }
            }
            concurrent = false; // program might have global state
        };
