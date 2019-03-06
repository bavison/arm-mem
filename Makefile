OBJS-V6L = memcmp-v6l.o memcpymove-v6l.o memset-v6l.o
OBJS-V7L = memcmp-test.o memcmp-v7l.o memcpymove-v7l.o memset-v7l.o
CFLAGS += -std=gnu99 -O2 -fno-inline

all: libarmmem-v6l.so libarmmem-v6l.a libarmmem-v7l.so libarmmem-v7l.a test

%.o: %.c
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -o $@ $^

%.o: %.S
	$(CROSS_COMPILE)gcc -c -o $@ $^

libarmmem-v6l.so: $(OBJS-V6L)
	$(CROSS_COMPILE)gcc -shared -o $@ $^

libarmmem-v6l.a: $(OBJS-V6L)
	$(CROSS_COMPILE)ar rcs $@ $^

libarmmem-v7l.so: $(OBJS-V7L)
	$(CROSS_COMPILE)gcc -shared -o $@ $^

libarmmem-v7l.a: $(OBJS-V7L)
	$(CROSS_COMPILE)ar rcs $@ $^

test: test.o
	$(CROSS_COMPILE)gcc -o $@ $^

clean:
	rm -rf *.o *.so *.a test
