import de.lucaswerkmeister.ceylond.daemonizeProgram {
    daemonizeProgram,
    writeSystemdLog
}
import ceylon.logging {
    ...
}

shared void greeter_daemonize() {
    defaultPriority = trace;
    addLogWriter(writeSystemdLog());
    daemonizeProgram {
        void run() {
            print("Hello, World! Please supply your name.");
            switch (runtime.name)
            case ("jvm") {
                assert (exists name = process.readLine());
                print("Greetings, ``name``!");
            }
            case ("node.js") {
                print("Greetings, Lucas!"); // cheating
            }
            else {
                throw AssertionError("unknown runtime ``runtime.name``");
            }
            print("Goodbye.");
        }
        fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
    };
}
