import de.lucaswerkmeister.ceylond {
    writeSystemdLog
}
import ceylon.logging {
    addLogWriter,
    defaultPriority,
    trace
}

shared void run() {
    addLogWriter(writeSystemdLog);
    defaultPriority = trace;
    assert (exists funName = process.arguments.first,
        exists fun = `package`.getFunction(funName));
    fun.invoke();
}
