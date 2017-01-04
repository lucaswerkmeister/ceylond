# Released under CC0; see LICENSE file.

# copy this Makefile to your project and set the following variables:
NAME := TODO-name-of-the-binary
SOCKET_PATH := /TODO/path/to/socket
LENGTH_SIZE := 2 # default value of makePacketBasedInstance
TYPE_SIZE := 1 # default value of makePacketBasedInstance
# if your program reads standard input, uncomment this:
# CFLAGS += -DSTDIN

CFLAGS += -Wall

$(NAME): client.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -DSOCKET_PATH=$(SOCKET_PATH) -DLENGTH_SIZE=$(LENGTH_SIZE) -DTYPE_SIZE=$(TYPE_SIZE) $^ $(LDFLAGS) $(LOADLIBES) $(LDLIBS) -o $@
