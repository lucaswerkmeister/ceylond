import de.lucaswerkmeister.ceylond.core {
    writeSystemdLog
}
import ceylon.logging {
    addLogWriter,
    defaultPriority,
    trace
}

shared void run() {
    if (!"--noDefaultLogWriter" in process.arguments) {
        addLogWriter(writeSystemdLog);
    }
    defaultPriority = trace;
    assert (exists funName = process.arguments.filter((s) => !s.startsWith("-")).first,
        exists fun = `package`.getFunction(funName));
    fun.invoke();
}
