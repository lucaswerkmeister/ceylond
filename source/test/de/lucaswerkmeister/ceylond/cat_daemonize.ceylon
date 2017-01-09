import de.lucaswerkmeister.ceylond.daemonizeProgram {
    daemonizeProgram,
    writeSystemdLog
}
import ceylon.logging {
    ...
}

shared void cat_daemonize() {
    defaultPriority = trace;
    addLogWriter(writeSystemdLog());
    daemonizeProgram {
        void run() {
            while (exists line = process.readLine()) {
                print(line);
            }
        }
        fd = switch (runtime.name) case ("jvm") 0 case ("node.js") 3 else -1;
    };
}
