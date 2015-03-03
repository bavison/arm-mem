OBJS = arm-mem.o memcmp.o memcpymove.o memcpymove-a7.o memset.o
CFLAGS += -std=gnu99 -O2

all: libarmmem.so libarmmem.a test

libarmmem.so: $(OBJS)
	$(CC) -shared -o $@ $^

libarmmem.a: $(OBJS)
	$(AR) rcs $@ $^

test: test.o
	$(CC) -o $@ $^

clean:
	rm -rf *.o *.so *.a test
