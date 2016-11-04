#include <errno.h>
#include <error.h>
#include <inttypes.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

#define SOCKET_NAME "/tmp/mysocket"

void testGreeting() {
  int ret, sock, len, type;
  ssize_t written;
  struct sockaddr_un addr;

  sock = socket(AF_UNIX, SOCK_STREAM, 0);
  if (sock < 0) error(EXIT_FAILURE, errno, "greeting socket");

  memset(&addr, 0, sizeof(struct sockaddr_un));

  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, SOCKET_NAME, sizeof(addr.sun_path) - 1);

  ret = connect(sock, (const struct sockaddr *) &addr, sizeof(struct sockaddr_un));
  if (ret < 0) error(EXIT_FAILURE, errno, "greeting connect");

  uint8_t data[] = {
    // 2-byte length
    0, 5,
    // 2-byte type
    0, 0,
    // content
    'L', 'u', 'c', 'a', 's'
  };
  written = write(sock, &data, sizeof(data));
  if (written < sizeof(data)) error(EXIT_FAILURE, errno, "greeting write");

  char *expRespCont = "Greetings, Lucas!\n";
  uint8_t resp[256];
  errno = 0;
  ret = read(sock, &resp, 2 + 2 + strlen(expRespCont));
  if (ret != 2 + 2 + strlen(expRespCont)) error(EXIT_FAILURE, errno, "unexpected greeting read response 1 length %d", ret);
  len = (resp[0] << 8) | resp[1];
  if (len != strlen(expRespCont)) error(EXIT_FAILURE, 0, "unexpected greeting length %d", len);
  type = (resp[2] << 8) | resp[3];
  if (type != 0) error(EXIT_FAILURE, 0, "unexpected greeting response type %d", type);
  if (strncmp(expRespCont, &resp[4], len)) error(EXIT_FAILURE, 0, "unexpected greeting response");

  expRespCont = "Goodbye.\n";
  errno = 0;
  ret = read(sock, &resp, 2 + 2 + strlen(expRespCont));
  if (ret != 2 + 2 + strlen(expRespCont)) error(EXIT_FAILURE, errno, "unexpected greeting read response 2 length %d", ret);
  len = (resp[0] << 8) | resp[1];
  if (len != strlen(expRespCont)) error(EXIT_FAILURE, 0, "unexpected close length %d", len);
  type = (resp[2] << 8) | resp[3];
  if (type != 0xFF) error(EXIT_FAILURE, 0, "unexpected close type %d", type);
  if (strncmp(expRespCont, &resp[4], len)) error(EXIT_FAILURE, 0, "unexpected close response");

  close(sock);
}

void testCatAndClose() {
  int ret, sock, len, type;
  ssize_t written;
  struct sockaddr_un addr;

  sock = socket(AF_UNIX, SOCK_STREAM, 0);
  if (sock < 0) error(EXIT_FAILURE, errno, "catAndClose socket");

  memset(&addr, 0, sizeof(struct sockaddr_un));

  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, SOCKET_NAME, sizeof(addr.sun_path) - 1);

  ret = connect(sock, (const struct sockaddr *) &addr, sizeof(struct sockaddr_un));
  if (ret < 0) error(EXIT_FAILURE, errno, "catAndClose connect");

  uint8_t data[] = {
    // 2-byte length
    0, 4,
    // 2-byte type
    0, 1,
    // content
    0xCA, 0xFE, 0xBA, 0xBE,
    // 2-byte length
    0, 0,
    // 2-byte type
    0, 0xFF
    // no content
  };
  written = write(sock, &data, sizeof(data)); // two packets in one transmission!
  if (written < sizeof(data)) error(EXIT_FAILURE, errno, "catAndClose write");

  uint8_t resp[256];
  errno = 0;
  ret = read(sock, &resp, 2 + 2 + 4);
  if (ret != 2 + 2 + 4) error(EXIT_FAILURE, errno, "cat read response");
  len = (resp[0] << 8) | resp[1];
  if (len != 4) error(EXIT_FAILURE, 0, "unexpected cat length %d", len);
  type = (resp[2] << 8) | resp[3];
  if (type != 1) error(EXIT_FAILURE, 0, "unexpected cat type %d", type);
  if (strncmp(&data[4], &resp[4], 4)) error(EXIT_FAILURE, 0, "unexpected cat response");

  errno = 0;
  ret = read(sock, &resp, 2 + 2 + 0);
  if (ret != 2 + 2 + 0) error(EXIT_FAILURE, errno, "close read response");
  len = (resp[0] << 8) | resp[1];
  if (len != 0) error(EXIT_FAILURE, 0, "unexpected close length %d", len);
  type = (resp[2] << 8) | resp[3];
  if (type != 0xFF) error(EXIT_FAILURE, 0, "unexpected close type %d", type);

  close(sock);
}

void testDie() {
  int ret, sock, len, type;
  ssize_t written;
  struct sockaddr_un addr;

  sock = socket(AF_UNIX, SOCK_STREAM, 0);
  if (sock < 0) error(EXIT_FAILURE, errno, "die socket");

  memset(&addr, 0, sizeof(struct sockaddr_un));

  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, SOCKET_NAME, sizeof(addr.sun_path) - 1);

  ret = connect(sock, (const struct sockaddr *) &addr, sizeof(struct sockaddr_un));
  if (ret < 0) error(EXIT_FAILURE, errno, "die connect");

  uint8_t data[] = {
    // 2-byte length
    0, 0,
    // 2-byte type
    0xFF, 0xFF
    // no content
  };
  written = write(sock, &data, sizeof(data));
  if (written < sizeof(data)) error(EXIT_FAILURE, errno, "die write");

  uint8_t resp[256];
  errno = 0;
  ret = read(sock, &resp, 2 + 2 + 0);
  if (ret != 2 + 2 + 0) error(EXIT_FAILURE, errno, "die read response 2");
  len = (resp[0] << 8) | resp[1];
  if (len != 0) error(EXIT_FAILURE, 0, "unexpected close length %d", len);
  type = (resp[2] << 8) | resp[3];
  if (type != 0xFFFF) error(EXIT_FAILURE, 0, "unexpected close type %d", type);
  close(sock);
}

int main(int argc, char *argv[]) {
  testGreeting();
  testCatAndClose();
  testDie();
}
