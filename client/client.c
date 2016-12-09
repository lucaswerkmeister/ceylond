#define _GNU_SOURCE

#include <errno.h>
#include <error.h>
#include <inttypes.h>
#include <langinfo.h>
#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

#ifndef SOCKET_PATH
#error "SOCKET_PATH must be defined"
#else
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define SOCKET_PATH_STR TOSTRING(SOCKET_PATH)
#endif

#ifndef LENGTH_SIZE
#define LENGTH_SIZE 2
#endif

#ifndef TYPE_SIZE
#define TYPE_SIZE 1
#endif

#define TYPE_LAUNCH 0x00
#define TYPE_ARGUMENT 0x01
#define TYPE_WORKING_DIRECTORY 0x02
#define TYPE_STDIN 0x03
#define TYPE_CLOSE 0x80
#define TYPE_STDOUT 0x81
#define TYPE_STDERR 0x82
#define TYPE_EXCEPTION 0x83
#define TYPE_STDIN_LONG 0x90
#define TYPE_STDOUT_LONG 0x91
#define TYPE_STDERR_LONG 0x92

/* name2buf and buf2name functions that convert a size-wide integer in network byte order */
#define CONVERSION(name, size)                           \
  uint8_t * name ## 2buf (uint64_t integer) {            \
    static uint8_t buf[size];                            \
    for (int i = 0; i < size; i++) {                     \
      buf[i] = (integer >> 8*(size-1-i)) & 0xFF;         \
    }                                                    \
    return buf;                                          \
  }                                                      \
  uint64_t buf2 ## name (uint8_t *buf) {                 \
    uint64_t res = 0;                                    \
    for (int i = 0; i < size; i++) {                     \
      res |= buf[i] << 8*(size-1-i);                     \
    }                                                    \
    return res;                                          \
  }

CONVERSION(integer, 8)
CONVERSION(length, LENGTH_SIZE)
CONVERSION(type, TYPE_SIZE)

int main(int argc, char *argv[]) {
  setlocale(LC_CTYPE, "");
  if (strcmp(nl_langinfo(CODESET), "UTF-8") != 0)
    error(EXIT_FAILURE, 0, "non-UTF-8 encoding (%s) not supported, please use an UTF-8 locale", nl_langinfo(CODESET));

  int ret, sock, argi, len;
  uint64_t length, type;
  ssize_t written;
  struct sockaddr_un addr;

  sock = socket(AF_UNIX, SOCK_STREAM, 0);
  if (sock < 0) error(EXIT_FAILURE, errno, "socket()");

  memset(&addr, 0, sizeof(struct sockaddr_un));

  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, SOCKET_PATH_STR, sizeof(addr.sun_path) - 1);

  ret = connect(sock, (const struct sockaddr *) &addr, sizeof(struct sockaddr_un));
  if (ret < 0) error(EXIT_FAILURE, errno, "connect()");

  // arguments
  for (argi = 1; argi < argc; argi++) {
    len = strlen(argv[argi]);
    written = write(sock, length2buf((uint64_t)len), LENGTH_SIZE);
    if (written < LENGTH_SIZE) error(EXIT_FAILURE, errno, "write(strlen(argv[%d]))", argi);
    written = write(sock, type2buf(TYPE_ARGUMENT), TYPE_SIZE);
    if (written < TYPE_SIZE) error(EXIT_FAILURE, errno, "write(TYPE_ARGUMENT/*argv[%d]*/)", argi);
    written = write(sock, argv[argi], len);
    if (written < len) error(EXIT_FAILURE, errno, "write(argv[%d])", argi); // TODO repeat writes?
  }
  // working directory
  char *cwd = get_current_dir_name();
  len = strlen(cwd);
  written = write(sock, length2buf((uint64_t)len), LENGTH_SIZE);
  if (written < LENGTH_SIZE) error(EXIT_FAILURE, errno, "write(strlen(cwd))");
  written = write(sock, type2buf(TYPE_WORKING_DIRECTORY), TYPE_SIZE);
  if (written < TYPE_SIZE) error(EXIT_FAILURE, errno, "write(TYPE_WORKING_DIRECTORY)");
  written = write(sock, cwd, len);
  if (written < len) error(EXIT_FAILURE, errno, "write(cwd)");
  free(cwd);
#ifdef STDIN
  // standard input
#ifndef STDIN_BUF_SIZE
#define STDIN_BUF_SIZE 4096
#elif STDIN_BUF_SIZE < 1
#error "STDIN_BUF_SIZE must be strictly positive if defined"
#endif
  char stdin[STDIN_BUF_SIZE];
  while ((len = read(0, stdin, STDIN_BUF_SIZE)) > 0) {
    written = write(sock, length2buf((uint64_t)len), LENGTH_SIZE);
    if (written < LENGTH_SIZE) error(EXIT_FAILURE, errno, "write(len/*stdin*/)", argi);
    written = write(sock, type2buf(TYPE_STDIN), TYPE_SIZE);
    if (written < TYPE_SIZE) error(EXIT_FAILURE, errno, "write(TYPE_STDIN)", argi);
    written = write(sock, stdin, len);
    if (written < len) error(EXIT_FAILURE, errno, "write(stdin)", argi);
  }
  if (len < 0) error(EXIT_FAILURE, errno, "read(stdin)");
#endif
  // launch
  written = write(sock, length2buf((uint64_t)0), LENGTH_SIZE);
  if (written < LENGTH_SIZE) error(EXIT_FAILURE, errno, "write(0/*launch*/)");
  written = write(sock, type2buf(TYPE_LAUNCH), TYPE_SIZE);
  if (written < TYPE_SIZE) error(EXIT_FAILURE, errno, "write(TYPE_LAUNCH)");

  // read response packets
  do {
    uint8_t lengthBuf[LENGTH_SIZE];
    uint8_t typeBuf[TYPE_SIZE];
    errno = 0;
    len = read(sock, lengthBuf, LENGTH_SIZE);
    if (len < LENGTH_SIZE) error(EXIT_FAILURE, errno, "read(length)");
    length = buf2length(lengthBuf);
    errno = 0;
    len = read(sock, typeBuf, TYPE_SIZE);
    if (len < TYPE_SIZE) error(EXIT_FAILURE, errno, "read(type)");
    type = buf2type(typeBuf);
    errno = 0;
    uint8_t *content = malloc(length);
    if (content == NULL && length > 0) error(EXIT_FAILURE, errno, "malloc(length = %" PRIu64 ")", length);
    errno = 0;
    len = read(sock, content, length);
    if (len < length) error(EXIT_FAILURE, errno, "read(content)");
    switch (type) {
    case TYPE_CLOSE: break;
    case TYPE_STDOUT:
    case TYPE_STDERR:
      errno = 0;
      len = write(type & 0x0F, content, length);
      if (len < length) error(EXIT_FAILURE, errno, "write()");
      break;
    case TYPE_EXCEPTION:
      errno = 0;
      len = write(2, content, length);
      if (len < length) error(EXIT_FAILURE, errno, "write(exception)");
      break;
    case TYPE_STDIN_LONG:
    case TYPE_STDOUT_LONG:
    case TYPE_STDERR_LONG: {
      char *msg;
      switch (type) {
      case TYPE_STDIN_LONG: msg = "input"; break;
      case TYPE_STDOUT_LONG: msg = "output"; break;
      case TYPE_STDERR_LONG: msg = "error"; break;
      }
      if (length != 4) error(EXIT_FAILURE, 0, "protocol error: 'standard %s too long' message must have exactly four bytes of content (got %" PRIu64 ")", msg, length);
      uint64_t limit = buf2integer(content);
      error(EXIT_FAILURE, 0, "standard %s exceeds configured limit of #%" PRIx64 " (%" PRIu64 ") bytes", msg, limit, limit);
    }
    default: error(EXIT_FAILURE, 0, "protocol error: unknown packet type #%" PRIx64 " (%" PRIu64 ")", type, type); break;
    }
    free(content);
  } while (type != TYPE_CLOSE);

  close(sock);
}
