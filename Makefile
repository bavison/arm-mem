OBJS = memcmp.o memcpy.o memmove.o mempcpy.o memset.o
CFLAGS += -std=c99 -O2

all: libarmmem.so libarmmem.a test

libarmmem.so: $(OBJS)
	$(CC) -shared -o $@ $^

libarmmem.a: $(OBJS)
	$(AR) rcs $@ $^

test: test.o
	$(CC) -o $@ $^

clean:
	rm -rf *.o *.so test
