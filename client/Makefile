SOCKET_PATH := /tmp/mysocket
NAME := client

CFLAGS += -Wall

$(NAME): client.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -DSOCKET_PATH=$(SOCKET_PATH) $^ $(LDFLAGS) $(LOADLIBES) $(LDLIBS) -o $@
