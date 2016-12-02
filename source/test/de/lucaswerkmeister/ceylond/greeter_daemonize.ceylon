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
            /*assert (exists name = process.readLine());
                print("Greetings, ``name``!`");
                print("Goodbye.");*/
        }
        fd = 0;
    };
}
