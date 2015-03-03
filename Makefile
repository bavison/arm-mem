OBJS = memcmp.o memcpymove.o memset.o
OBJS-A7 = memcpymove-a7.o
CFLAGS += -std=c99 -O2

all: libarmmem.so libarmmem.a libarmmem-a7.so libarmmem-a7.a test

%.o: %.c
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -o $@ $^

%.o: %.S
	$(CROSS_COMPILE)gcc -c -o $@ $^

libarmmem.so: $(OBJS)
	$(CROSS_COMPILE)gcc -shared -o $@ $^

libarmmem.a: $(OBJS)
	$(CROSS_COMPILE)ar rcs $@ $^

libarmmem-a7.so: $(OBJS-A7)
	$(CROSS_COMPILE)gcc -shared -o $@ $^

libarmmem-a7.a: $(OBJS-A7)
	$(CROSS_COMPILE)ar rcs $@ $^

test: test.o
	$(CROSS_COMPILE)gcc -o $@ $^

clean:
	rm -rf *.o *.so *.a test
