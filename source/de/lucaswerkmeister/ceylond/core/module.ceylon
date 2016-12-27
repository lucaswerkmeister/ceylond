"""A module for writing Ceylon daemons
   that communicate over a system-provided socket.

   ## Usage

   The simplest way to write a daemon is to use one of the abstractions layered over this module,
   such as `de.lucaswerkmeister.ceylond.recordBased` for string records separated by a separator sequence like `"\n"` or `":"`,
   or `de.lucaswerkmeister.ceylond.packetBased` for packets with a length and (optionally) a type.
   You can also daemonize a full, existing program with `de.lucaswerkmeister.ceylond.deamonizeProgram`.

   This module itself offers an asynchronous, callback-based server that sends and receives bytes.
   Each instance mainly consists of a callback that is called whenever data is read from the socket;
   it can also write to the socket and register a callback to be called when the write is finished.
   Per-instance error handling may also be configured.

   This implements a basic “`cat`” server which simply sends back everything it receives:

   ~~~
   shared void run() => start {
       function instance(void write(ByteBuffer content, WriteCallback callback), void close()) {
           void read(ByteBuffer content) {
               write(content, noop);
           }
           return [read, logAndAbort(`module`)];
       }
       fd = 3;
   };
   ~~~

   For details, please see the documentation of [[start]] and its parameters.

   The server process should inherit a socket file descriptor from the process that launched it,
   e. g. the *inetd* superserver (or a derivative like *xinetd*) or the *systemd* system manager.
   The choice of file descriptor (the `fd` parameter above) depends on the parent process.
   For the JS backend, Node must be started directly (not via `ceylon run-js`);
   for the JVM backend, `ceylon run` may also be avoided through `ceylon fat-jar`.

   The following systemd unit files may be used as a baseline for daemon unit files
   (placed, for example, in `/etc/systemd/system/`):

   ~~~desktop
   # ceylond.service
   [Service]
   # JVM backend
   ExecStart=/usr/bin/java -jar /path/to/ceylond.jar
   # JS backend
   ExecStart=/usr/bin/node -e "require('de/lucaswerkmeister/ceylond/1.0.0/de.lucaswerkmeister.ceylond-1.0.0').run()"
   Environment=NODE_PATH=/path/to/node_modules

   # ceylond.socket
   [Socket]
   ListenStream=/var/run/ceylond/ceylond.sock
   ~~~

   The daemon can then be activated with `systemctl start ceylond.socket`
   and permanently enabled with `systemctl enable ceylond.socket`.

   ## Logging

   This module (and its companion modules, listed above)
   makes use of [[module ceylon.logging]].
   If you [[register|ceylon.logging::addLogWriter]] a log writer,
   it will also receive messages from this module.

   This module also includes a log writer that emits messages to standard error
   in a format recognized by the systemd journal: [[writeSystemdLog]].
   When running under systemd, this format is preferred to `ceylon.logging`’s default writer.

   ## Backend-specific limitations

   - On the JVM, this module looks at `IOException` error messages to determine their cause.
     Java localizes those messages, so it’s recommended to run Java with `LC_MESSAGES=C`.
   - On Node.js, connections to non-concurrent servers
     that are attempted while the server is handling another connection
     are not accepted once the server becomes ready again –
     only connections that are newly made when the server is free succeed.
   - File descriptor support varies across backends;
     see the documentation of [[start.fd]] for details."""
native ("jvm", "js") module de.lucaswerkmeister.ceylond.core "1.0.0" {
    shared import ceylon.buffer "1.3.1";
    shared import ceylon.logging "1.3.1";
    import ceylon.collection "1.3.1";
    native ("jvm") import java.base "7";
    native ("jvm") import ceylon.interop.java "1.3.1";
}
