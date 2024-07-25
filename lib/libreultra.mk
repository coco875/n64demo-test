O_FILES += lib/ultralib/build/L/libgultra/libgultra.a

lib/ultralib/build/L/libgultra/libgultra.a:
	make -C lib/ultralib VERSION=L TARGET=libgultra FIXUPS=1 CROSS=$(CROSS)