.PHONY: all clean mrproper

MOON_FILES = $(wildcard test/*.moon) $(wildcard ./*.moon)
LUA_FILES = $(patsubst %.moon, %.lua, $(MOON_FILES))

all: $(LUA_FILES)

clean:
	rm -f $(LUA_FILES)

mrproper: clean

%.lua: %.moon
	moonc $<
