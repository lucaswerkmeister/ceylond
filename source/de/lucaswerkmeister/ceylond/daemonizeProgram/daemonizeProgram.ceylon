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

 - `#80` (128): connection closes.
   The content is a 4-byte integer in network byte order,
   indicating the exit code ([[process.exit]]’s argument;
   `process.exit` throws if called with a number that does not fit in four bytes),
   or `0` if the [[run]] function returned normally,
   or `1` if the [[run]] function threw an exception,
   or `#7FFFFFF0` (2147483632) if standard input was exceeded (see [[maximumStandardInput]]),
   or `#7FFFFFF1` (2147483633) if standard output was exceeded (see [[maximumStandardOutput]]),
   or `#7FFFFFF2` (2147483634) if standard error was exceeded (see [[maximumStandardError]]).
   A packet of this type is always sent on termination
   (unless the packet-based protocol itself is violated),
   and it is always the last packet;
   the socket is closed once this packet has been sent.
 - `#81` (129): standard output.
   All standard output produced by the program via [[process.writeLine]] and similar functions
   is stored in a buffer and finally sent in a packet of this type.
   Boundaries between writes are not preserved.
   (On the JVM backend, no encoding is specified, and the same advice as for standard input (`#03`, see above) applies;
   on the JS backend, the buffer is UTF-8 encoded.)
 - `#82` (130): standard error.
   Analogous to standard output (`#81`, see above).
 - `#83` (131): exception stacktrace.
   If the program threw an exception,
   a packet of this type is sent,
   containing the UTF-8 encoded stack trace.
 - `#90` (144): standard input too long.
   This packet is sent when the a received standard input packet
   bumps the total number of standard input bytes received
   above the application-configured [[limit|maximumStandardInput]].
   It contains that limit as a 4-byte integer in network byte order.
 - `#91` (145): standard output too long.
   This packet is sent when a write to standard output by the application
   exceeds the application-configured [[limit|maximumStandardOutput]].
   It contains that limit as a 4-byte integer in network byte order.
 - `#92` (146): standard error too long.
   Analogous to standard output too long (`#91`, see above)."
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
    Integer lengthSize = 2,
    "The size of the type length.
     The default of 1 is sufficient for all understood types,
     but a higher value may be desirable for alignment purpose."
    Integer typeSize = 1,
    "The maximum number of bytes accepted on standard input.
     If this is not [[null]] and is exceeded by some standard input packet,
     the daemon sends “standard input exceeded” (`#90`) and “exit” (`#80`) packets
     and then closes the connection.
     (Truncating the input in a meaningful way, if desired,
     is then the responsibility of the client program.)"
    Integer? maximumStandardInput = null,
    "The maximum number of bytes accepted on standard output.
     If this is not [[null]] and exceeded by some write to standard output,
     an exception is immediately thrown.
     If the [[run]] function does not catch this error,
     the program is terminated;
     the daemon sends “standard output exceeded” (`#91`) and “exit” (`#80`) packets
     and then closes the connection."
    Integer? maximumStandardOutput = null,
    "The maximum number of bytes accepted on standard error.
     If this is not [[null]] and exceeded by some write to standard error,
     an exception is immediately thrown.
     If the [[run]] function does not catch this error,
     the program is terminated;
     the daemon sends “standard error exceeded” (`#92`) and “exit” (`#80`) packets
     and then closes the connection."
    Integer? maximumStandardError = null,
    "See [[makePacketBasedInstance.maximumLength]]."
    Integer maximumPacketLength = 256^lengthSize - 1)(void write(ByteBuffer content, WriteCallback callback), void close()) {
    return makePacketBasedInstance {
        function instance(void write(ByteBuffer content, Integer type, WriteCallback callback), void close()) {
            log.trace("creating daemonizeProgram instance");
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
                log.trace("added argument no. ``arguments.size``");
            }
            void readWorkingDirectory(ByteBuffer content) {
                "Working directory can only be set once"
                assert (!workingDirectory exists);
                "Program must not be launched yet"
                assert (!launched);
                workingDirectory = utf8.decode(content);
                log.trace("set working directory to `` workingDirectory else "" ``");
            }
            void readStandardInput(ByteBuffer content) {
                "Program must not be launched yet"
                assert (!launched);
                try {
                    grow(standardInput, content.available, maximumStandardInput, StandardInputExceeded);
                } catch (StandardInputExceeded e) {
                    log.info("standard input limit (``e.limit``) exceeded");
                    write(intToBuffer(e.limit, 4), #90, noop);
                    write(intToBuffer(#7FFFFFF0, 4), #80, close);
                }
                log.trace("adding ``content.available`` bytes of standard input");
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
                log.trace("setting up program launch");
                variable value args = arguments.sequence();
                if (exists wd = workingDirectory) {
                    args = argumentsMap(args, wd);
                }
                setProcessArguments(args);
                log.trace("set process arguments");
                trapProcessExit {
                    void trap(Integer exitCode) {
                        throw ProcessExit(exitCode);
                    }
                };
                log.trace("trapped process.exit()");
                standardInput.flip();
                value resetStdin = setStandardInput(standardInput);
                log.trace("set standard input");
                value resetStdout = setStandardOutput(standardOutput, maximumStandardOutput);
                value resetStderr = setStandardError(standardError, maximumStandardError);
                log.trace("set standard output and error");
                void writeStreams() {
                    standardOutput.flip();
                    write(standardOutput, #81, noop);
                    standardError.flip();
                    write(standardError, #82, noop);
                }
                void resetStreams() {
                    resetStdin();
                    resetStdout();
                    resetStderr();
                }
                try {
                    log.info("launching program with program.arguments = [``", ".join(args.map((a) => "\"``a``\""))``], workingDirectory = `` workingDirectory else "<null>" ``, and ``standardInput.available`` bytes of standard input");
                    run();
                    log.info("program returned normally");
                    resetStreams();
                    writeStreams();
                    write(intToBuffer(0, 4), #80, close);
                } catch (ProcessExit pe) {
                    log.info("program terminated with ``pe.message``");
                    resetStreams();
                    writeStreams();
                    write(intToBuffer(pe.exitCode, 4), #80, close);
                } catch (StandardOutputExceeded e) {
                    log.error("standard output limit (``e.limit``) exceeded");
                    resetStreams();
                    write(intToBuffer(e.limit, 4), #91, noop);
                    write(intToBuffer(#7FFFFFF1, 4), #80, close);
                } catch (StandardErrorExceeded e) {
                    log.error("standard error limit (``e.limit``) exceeded");
                    resetStreams();
                    write(intToBuffer(e.limit, 4), #92, noop);
                    write(intToBuffer(#7FFFFFF2, 4), #80, close);
                } catch (Throwable t) {
                    log.error("program terminated with unknown Throwable", t);
                    resetStreams();
                    writeStreams();
                    StringBuilder stackTrace = StringBuilder();
                    printStackTrace(t, stackTrace.append);
                    write(utf8.encodeBuffer(stackTrace), #83, noop);
                    write(intToBuffer(1, 4), #80, close);
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
        lengthSize = lengthSize;
        typeSize = typeSize;
        maximumLength = maximumPacketLength;
    }(write, close);
}

"Turns a normal program ([[run]]) into a daemon
 that runs one instance of the program per connection.
 Only one instance of the program is run at a time,
 to avoid interference between multiple instances via global state.
 (However, the program needs to take care of resetting such state at the beginning or end itself.)"
shared void daemonizeProgram(
    "See [[makeDaemonizeProgramInstance.run]]."
    void run(),
    "See [[start.fd]]."
    Integer fd,
    "See [[makeDaemonizeProgramInstance.argumentsMap]]."
    String[] argumentsMap(String[] arguments, String? workingDirectory) => arguments,
    "See [[makeDaemonizeProgramInstance.lengthSize]]."
    Integer lengthSize = 2,
    "See [[makeDaemonizeProgramInstance.typeSize]]."
    Integer typeSize = 1,
    "See [[makeDaemonizeProgramInstance.maximumStandardInput]]."
    Integer? maximumStandardInput = null,
    "See [[makeDaemonizeProgramInstance.maximumStandardOutput]]."
    Integer? maximumStandardOutput = null,
    "See [[makeDaemonizeProgramInstance.maximumStandardError]]."
    Integer? maximumStandardError = null,
    "See [[makePacketBasedInstance.maximumLength]]."
    Integer maximumPacketLength = 256^lengthSize - 1)
        => start {
            instance = makeDaemonizeProgramInstance {
                run = run;
                argumentsMap = argumentsMap;
                lengthSize = lengthSize;
                typeSize = typeSize;
                maximumStandardInput = maximumStandardInput;
                maximumStandardOutput = maximumStandardOutput;
                maximumStandardError = maximumStandardError;
                maximumPacketLength = maximumPacketLength;
            };
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
