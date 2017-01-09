# ceylond

A collection of modules to write daemons that communicate over a system-provided socket in Ceylon.

## Short example

This implements a basic “`cat`” server which simply sends back everything it receives:

```ceylon
import de.lucaswerkmeister.ceylond.core { ... }

shared void run() => start {
    function instance(void write(ByteBuffer content, WriteCallback callback), void close()) {
        void read(ByteBuffer content) {
            write(content, noop);
        }
        return [read, logAndAbort(`module`)];
    }
    fd = 3;
};
```

You can build it for either backend:
```sh
# JVM
ceylon compile,fat-jar com.example.cat
# JS
ceylon compile-js com.example.cat
ceylon copy --js --with-dependencies --include-language --out node_modules com.example.cat
```
and run it, for example, with `systemd-socket-activate`:
```sh
systemd-socket-activate \
    -E LC_ALL=en_US.UTF-8 \
    -E LC_MESSAGES=C \
    --listen /run/cat \
    # JVM
    /usr/bin/java -jar com.example.cat-1.0.0.jar
    # JS
    /usr/bin/node -e "require('com/example/cat/1.0.0/com.example.cat-1.0.0').run()
```

## Motivation

Both current backends for the Ceylon programming language, JVM and JS,
run on highly sophisticated virtual machines.
Those virtual machines have a non-negligible startup cost (over 50 μs)
and optimize the programs they run over time
as they learn more about the runtime behavior of the programs.
For both these reasons, they are not ideal for short-lived, frequently-run programs,
such as programs intended for command line or shell script usage.

Instead of abandoning the advantages of the virtual machines,
we can set up a server version of the programs.
The server runs continuously and listens on a socket (e. g. a Unix Domain Socket);
each time a connection is made, it runs the original program,
then returns to listening for the next connection.
The client then, instead of running the program,
simply needs to communicate with the server over the socket,
a task which is readily implemented in a systems language like C.
We get the best of both worlds:
there is almost no startup overhead
(the C client is quick to start,
and the server is already running),
and the server can still benefit from advanced optimizations by the virtual machine,
since it can run for hours, days, or even months,
continuously serving new connections.

## Background

On Unix, network communication is done using a *socket*,
which is a file descriptor created by the `socket(2)` system call
and bound to an address using the `bind(2)` system call.
A server applications marks the socket as a passive one with `listen(2)`
and then repeatedly `accept(2)`s connections on it.
Each `accept(2)` call returns a new file descriptor for the connection,
which the server may then `read(2)` from and `write(2)` to just like any other file descriptor.

Since the socket is just a file descriptor,
it is inherited by new child processes.
It is thus possible to set up a socket in a parent program
and the pass it to a potentially less privileged child program,
which then accepts connections on the socket and handles then.
In this pattern, the parent program is called a *super-server*.
The pattern was first popularized by the *inetd* daemon
(a modern derivative that may still be found in many GNU/Linux distributions is *xinetd*),
but is today also employed by *systemd*
under the moniker of *socket activation*.
Under this schema, the service manager (system or user instance) sets up the socket
and spawns a service which inherits the socket file descriptor (usually as file descriptor 3)
as soon as a connection to the socket is made.

This makes it possible to use less common address families,
like Unix Domain Sockets (`AF_UNIX` – the address is a file system entry),
in programming languages that don’t directly support those address families,
as long as they can deal with an inherited socket file descriptor:
the socket is then simply set up by the system (inetd, systemd, …).

## The ceylond modules

- `de.lucaswerkmeister.ceylond.core`:
  This module handles the socket setup itself,
  as described in the last paragraph of the Background section,
  on both backends.
  It implements an asynchronous byte stream server
  (a synchronous one is not possible on Node.js):
  one registers a callback that is called whenever some data to read arrives,
  and can write data without waiting for the write to go through
  (instead registering another callback to be invoked when the write is done).
  The only data format offered is raw bytes,
  and while the module does ensure that no data is lost,
  there is no concept of messages or packets:
  boundaries between reads or writes may be lost
  through fragmentation or reassembly.
- `de.lucaswerkmeister.ceylond.recordBased`:
  One of two abstractions on top of the core module.
  The data format is no longer bytes, but text
  (via a user-specified encoding, by default UTF-8).
  The text consists of *records*, separated by a *record separator*,
  which is a user-specified string.
  The default record separator is a single newline character, `"\n"`,
  making each record one line and providing a *line-based daemon*.
  Such a daemon can easily be used from the command line
  with tools like `nc` (netcat) and `socat` (socket cat).
  Many internet protocols, including HTTP and SMTP,
  also use a similar format,
  but with `"\r\n"` as the record separator;
  see the module documentation for a simple HTTP server.
- `de.lucaswerkmeister.ceylond.packetBased`:
  The other abstraction on top of the core module.
  A *packet* is a series of bytes, optionally annotated with an integer *type*.
  When writing a packet, the module adds the packet length and type;
  when reading a packet, the module parses the length and type
  and then reads data until the packet is complete,
  finally delivering a complete packet to the application.
  The size of the packet length and type are configurable
  (a type size of 0 bytes disables the type mechanism completely),
  and a maximum packet length may also be imposed
  to prevent malicious clients causing the server to allocate large amounts of memory.
- `de.lucaswerkmeister.ceylond.daemonizeProgram`:
  Finally, this implements the original motivation
  on top of the `packetBased` module:
  You supply a `run` function,
  and this module turns it into a daemon as described in the Motivation section,
  taking care of process arguments, standard I/O,
  and some other mechanisms – see the module documentation for details.
  A sample client is also provided in the `client/` subdirectory.
  (Note that standard input, if used,
  must be sent to the daemon before the program starts;
  interactive dialogs or similar interfaces
  must be emulated by the client.)

## License

The content of this repository is released under the LGPLv3
as provided in the `LICENSE` file that accompanied this code.

Additionally, the `client/` subdirectory is released under CC0.
