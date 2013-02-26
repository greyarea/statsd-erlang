all: compile

clean:
	@./rebar clean

compile:
	@./rebar compile

.PHONY: all clean compile
