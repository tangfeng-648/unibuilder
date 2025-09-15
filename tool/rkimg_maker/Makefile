CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -Wno-stringop-truncation
LDFLAGS ?= -lcrypto

TARGETS = afptool img_maker
DEPS    = Makefile rkafp.h rkcrc.h

all: $(TARGETS)

%: %.c $(COMMON) $(DEPS)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

.PHONY: clean uninstall

clean:
	rm -f $(TARGETS)
