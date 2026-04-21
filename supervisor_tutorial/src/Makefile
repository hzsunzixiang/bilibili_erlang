.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

ERL = erl -boot start_clean

MODS := $(patsubst %.erl,%, $(wildcard *.erl))

.PHONY: all compile clean run_worker run_pool run_all help

all: compile

compile: ${MODS:%=%.beam}

run_worker: compile
	erl -noshell -s worker_sup demo -s init stop

run_pool: compile
	erl -noshell -s pool_sup demo -s init stop

run_all: compile
	@echo "=========================================="
	@echo "  Running all supervisor demos"
	@echo "=========================================="
	erl -noshell \
		-s worker_sup demo \
		-s pool_sup demo \
		-s init stop

clean:
	rm -f *.beam erl_crash.dump

help:
	@echo "Available targets:"
	@echo "  make compile    - Compile all .erl files"
	@echo "  make run_worker - Run worker_sup demo (one_for_one)"
	@echo "  make run_pool   - Run pool_sup demo (simple_one_for_one)"
	@echo "  make run_all    - Run all demos sequentially"
	@echo "  make clean      - Remove compiled files"
