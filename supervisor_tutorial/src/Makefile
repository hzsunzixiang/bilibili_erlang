.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

ERL = erl -boot start_clean

MODS := $(patsubst %.erl,%, $(wildcard *.erl))

.PHONY: all compile clean run_worker run_pool_pid run_pool_local run_pool_global run_all help

all: compile

compile: ${MODS:%=%.beam}

run_worker: compile
	erl -noshell -s worker_sup demo -s init stop

run_pool_pid: compile
	erl -noshell -s pool_sup_pid demo -s init stop

run_pool_local: compile
	erl -noshell -s pool_sup_local demo -s init stop

run_pool_global: compile
	erl -noshell -s pool_sup_global demo -s init stop

run_all: compile
	@echo "=========================================="
	@echo "  Running all supervisor demos"
	@echo "=========================================="
	erl -noshell \
		-s worker_sup demo \
		-s pool_sup_pid demo \
		-s pool_sup_local demo \
		-s pool_sup_global demo \
		-s init stop

clean:
	rm -f *.beam erl_crash.dump

help:
	@echo "Available targets:"
	@echo "  make compile        - Compile all .erl files"
	@echo "  make run_worker     - Run worker_sup demo (one_for_one)"
	@echo "  make run_pool_pid   - Run pool_sup_pid demo (nameless, Pid)"
	@echo "  make run_pool_local - Run pool_sup_local demo ({local, Name})"
	@echo "  make run_pool_global- Run pool_sup_global demo ({global, Name})"
	@echo "  make run_all        - Run all demos sequentially"
	@echo "  make clean          - Remove compiled files"
