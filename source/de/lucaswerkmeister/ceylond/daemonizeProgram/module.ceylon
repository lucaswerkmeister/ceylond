"This module allows you to turn a regular Ceylon program into a daemonized version.
 On each connection, the daemon will accept command line arguments, a working directory, and standard input.
 It will then set up the environment for the program, and launch it.
 Afterwards, the program’s output and result are sent over the connection again.
 A simple client that just communicates with the daemon can then be used in place of the original program,
 eliminating VM startup time and taking advantage of VM optimizations for long-running programs.
 One example client may be found in the `client/` directory of the source code repository of this module;
 if you wish to implement your own client,
 please consult the detailed protocol description in the [[makeDaemonizeProgramInstance]] documentation.

 ~~~
 import com.example.program { program=run }
 import de.lucaswerkmeister.ceylond.daemonizeProgram { daemonizeProgram }

 shared void run() => daemonizeProgram { program; fd = 3; };
 ~~~

 The following mechanisms are trapped/replaced and may be used by the program:
 - standard input, output and error
 - [[process.exit]]
 - [[process.arguments]], including named arguments
 - uncaught exceptions from the `run` function

 The working directory of the daemon process remains unchanged,
 but a small handler may be [[registered|makeDaemonizeProgramInstance.argumentsMap]] to adapt paths in [[process.arguments]] as needed.

 The following mechanisms are not trapped/replaced and should not be used by the program:
 - [[process.propertyValue]]
 - [[process.environmentVariableValue]]
 - any backend-specific mechanism

 ## Logging

 This module provides a custom version of the core module’s [[de.lucaswerkmeister.ceylond.core::writeSystemdLog]]
 that does not interfere with trapped standard error: see [[writeSystemdLog]]."
native ("jvm", "js") module de.lucaswerkmeister.ceylond.daemonizeProgram "1.0.0" {
    shared import de.lucaswerkmeister.ceylond.packetBased "1.0.0";
    import ceylon.collection "1.3.1";
    native ("jvm") import java.base "7";
    native ("jvm") import ceylon.interop.java "1.3.1";
}
