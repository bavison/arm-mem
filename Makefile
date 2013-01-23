OBJS = memcmp.o memcpy.o memmove.o memset.o
CFLAGS += -std=c99

libarmmem.so: $(OBJS)
	$(CC) -shared -o $@ $^

test: test.o
	$(CC) -o $@ $^

clean:
	rm -rf *.o *.so test
