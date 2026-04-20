.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

ERL = erl -boot start_clean

MODS := $(patsubst %.erl,%, $(wildcard *.erl))

.PHONY: all compile clean run_counter run_local run_global help

all: compile

compile: ${MODS:%=%.beam}

run_counter: compile
	erl -noshell -s counter_server demo -s init stop

run_local: compile
	erl -noshell -s local_counter demo -s init stop

run_global: compile
	erl -noshell -s global_counter demo -s init stop

clean:
	rm -f *.beam erl_crash.dump

help:
	@echo "Available targets:"
	@echo "  make compile     - Compile all .erl files"
	@echo "  make run_counter - Run counter_server demo"
	@echo "  make run_local   - Run local_counter demo"
	@echo "  make run_global  - Run global_counter demo"
	@echo "  make clean       - Remove compiled files"
