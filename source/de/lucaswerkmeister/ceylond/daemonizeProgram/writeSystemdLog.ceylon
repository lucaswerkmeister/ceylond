import ceylon.logging {
    ...
}
import java.lang {
    System
}

"A version of [[de.lucaswerkmeister.ceylond.core::writeSystemdLog]]
 that continues to log to the real standard error even after standard error has been redirected for the program.
 Usage:

     addLogWriter(writeSystemdLog());

 (Note that this function has one parameter list more than the original one;
 the first invocation captures the real standard error.)"
shared Anything(Priority, Category, String, Throwable?) writeSystemdLog() {
    value writeErrorLine = package.writeErrorLine();
    return (Priority priority, Category category, String message, Throwable? throwable) {
        String sd_level;
        switch (priority)
        case (trace | debug) { sd_level = "<7>"; } // SD_DEBUG
        case (info) { sd_level = "<6>"; } // SD_INFO
        case (warn) { sd_level = "<4>"; } // SD_WARNING
        case (error) { sd_level = "<3>"; } // SD_ERR
        case (fatal) { sd_level = "<2>"; } // SD_CRIT
        writeErrorLine(sd_level + message);
        if (exists throwable) {
            printStackTrace(throwable, (String string) {
                value message = string.trimTrailing("\r\n".contains);
                if (message.empty) {
                    return;
                }
                for (line in message.lines) {
                    writeErrorLine(sd_level + line);
                }
            });
        }
    };
}

native Anything(String) writeErrorLine();
native ("jvm") Anything(String) writeErrorLine() {
    value syserr = System.err;
    return (String line) => syserr.println(line);
}
native ("js") Anything(String) writeErrorLine() {
    Boolean usesProcess;
    Boolean usesConsole;
    dynamic {
        usesProcess = eval("(typeof process !== 'undefined') && (process.stderr !== undefined)");
        usesConsole = !usesProcess && eval("(typeof console !== 'undefined') && (console.error !== undefined)");
    }
    if (usesProcess) {
        dynamic {
            dynamic psw = eval("process.stderr").write;
            return (String line) => psw(line + operatingSystem.newline);
        }
    } else if (usesConsole) {
        dynamic {
            return console.error;
        }
    } else {
        return noop;
    }
}
