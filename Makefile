OBJS = arm-mem.o memcmp.o memcpymove.o memcpymove-a7.o memset.o
CFLAGS += -std=gnu99 -O2

all: libarmmem.so libarmmem.a test

%.o: %.c
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -o $@ $^

%.o: %.S
	$(CROSS_COMPILE)gcc -c -o $@ $^

libarmmem.so: $(OBJS)
	$(CROSS_COMPILE)gcc -shared -o $@ $^

libarmmem.a: $(OBJS)
	$(CROSS_COMPILE)ar rcs $@ $^

test: test.o
	$(CROSS_COMPILE)gcc -o $@ $^

clean:
	rm -rf *.o *.so *.a test
