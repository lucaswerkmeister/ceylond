import ceylon.buffer {
    ByteBuffer
}
import ceylon.buffer.charset {
    utf8
}
import ceylon.interop.java {
    javaByteArray,
    javaClassFromInstance
}
import java.lang {
    System
}
import java.io {
    ByteArrayInputStream,
    OutputStream,
    PrintStream
}

"Sets the standard input to the contents of the given byte buffer.
 Reading from standard input will produce the contents of this buffer and nothing else.

 (Note that the JS backend does not support reading from standard input;
 this function is a no-op on that backend, and functions like [[process.readLine]] will continue to return [[null]].)"
native void setStandardInput(ByteBuffer standardInput);
"Sets the standard output to the given byte buffer.
 Every write to standard output is appended to the byte buffer (which is resized as needed).
 The collected content of standard output may then later be retrieved from that buffer.

 If the [[limit]] is not [[null]], and the output buffer would have to grow beyond the limit,
 a [[StandardOutputExceeded]] exception is thrown.

 (Note that all writes are presented as one contiguous byte buffer;
 boundaries between writes are not preserved.)"
native void setStandardOutput(ByteBuffer standardOutput, Integer? limit);
"Sets the standard error to the given byte buffer.
 Every write to standard error is appended to the byte buffer (which is resized as needed).
 The collected content of standard error may then later be retrieved from that buffer.

 If the [[limit]] is not [[null]], and the output buffer would have to grow beyond the limit,
 a [[StandardErrorExceeded]] exception is thrown.

 (Note that all writes are presented as one contiguous byte buffer;
 boundaries between writes are not preserved.)"
native void setStandardError(ByteBuffer standardError, Integer? limit);

native ("jvm") void setStandardInput(ByteBuffer standardInput) {
    System.setIn(ByteArrayInputStream(javaByteArray(standardInput.array), 0, standardInput.available));
    value stdinReaderField = javaClassFromInstance(process).getDeclaredField("stdinReader");
    stdinReaderField.accessible = true;
    stdinReaderField.set(process, null);
}
native ("jvm") void setStandardOutput(ByteBuffer standardOutput, Integer? limit) {
    System.setOut(PrintStream(object extends OutputStream() {
        shared actual void write(Integer byte) {
            grow(standardOutput, 1, limit, StandardOutputExceeded);
            standardOutput.put(byte.byte);
        }
    }));
}
native ("jvm") void setStandardError(ByteBuffer standardError, Integer? limit) {
    System.setErr(PrintStream(object extends OutputStream() {
        shared actual void write(Integer byte) {
            grow(standardError, 1, limit, StandardErrorExceeded);
            standardError.put(byte.byte);
        }
    }));
}

native ("js") void setStandardInput(ByteBuffer standardInput) {
    // noop
}
native ("js") void setStandardOutput(ByteBuffer standardOutput, Integer? limit) {
    Boolean usesProcess;
    Boolean usesConsole;
    dynamic {
        usesProcess = eval("(typeof process !== 'undefined') && (process.stdout !== undefined)");
        usesConsole = !usesProcess && eval("(typeof console !== 'undefined') && (console.log !== undefined)");
    }
    if (usesProcess) {
        // overwrite process.stdout.write
        dynamic {
            dynamic stdout = eval("process.stdout");
            stdout.write = (String s) {
                value content = utf8.encodeBuffer(s);
                grow(standardOutput, content.available, limit, StandardOutputExceeded);
                while (content.hasAvailable) {
                    standardOutput.put(content.get());
                }
            };
        }
    } else if (usesConsole) {
        // overwrite console.log
        dynamic {
            console.log = (String s) {
                value content = utf8.encodeBuffer(s + operatingSystem.newline);
                grow(standardOutput, content.available, limit, StandardOutputExceeded);
                while (content.hasAvailable) {
                    standardOutput.put(content.get());
                }
            };
        }
    } else {
        // noop
    }
}
native ("js") void setStandardError(ByteBuffer standardError, Integer? limit) {
    Boolean usesProcess;
    Boolean usesConsole;
    dynamic {
        usesProcess = eval("(typeof process !== 'undefined') && (process.stderr !== undefined)");
        usesConsole = !usesProcess && eval("(typeof console !== 'undefined') && (console.error !== undefined)");
    }
    if (usesProcess) {
        // overwrite process.stderr.write
        dynamic {
            dynamic stderr = eval("process.stderr");
            stderr.write = (String s) {
                value content = utf8.encodeBuffer(s);
                grow(standardError, content.available, limit, StandardErrorExceeded);
                while (content.hasAvailable) {
                    standardError.put(content.get());
                }
            };
        }
    } else if (usesConsole) {
        // overwrite console.error
        dynamic {
            console.error = (String s) {
                value content = utf8.encodeBuffer(s + operatingSystem.newline);
                grow(standardError, content.available, limit, StandardErrorExceeded);
                while (content.hasAvailable) {
                    standardError.put(content.get());
                }
            };
        }
    } else {
        // noop
    }
}
