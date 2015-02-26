OBJS = memcmp.o memcpymove.o memset.o
OBJS-A7 = memcpymove-a7.o
CFLAGS += -std=c99 -O2

all: libarmmem.so libarmmem.a libarmmem-a7.so libarmmem-a7.a test

libarmmem.so: $(OBJS)
	$(CC) -shared -o $@ $^

libarmmem.a: $(OBJS)
	$(AR) rcs $@ $^

libarmmem-a7.so: $(OBJS-A7)
	$(CC) -shared -o $@ $^

libarmmem-a7.a: $(OBJS-A7)
	$(AR) rcs $@ $^

test: test.o
	$(CC) -o $@ $^

clean:
	rm -rf *.o *.so test
