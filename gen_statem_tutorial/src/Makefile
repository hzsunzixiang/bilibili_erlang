.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

ERL = erl -boot start_clean

MODS := $(patsubst %.erl,%, $(wildcard *.erl))

.PHONY: all compile clean run_state run_handle_event run_common run_stop run_event_timeout run_generic_timeout run_erlang_timer run_postpone run_enter run_inserted run_complex run_selective run_all help

all: compile

compile: ${MODS:%=%.beam}

run_state: compile
	erl -noshell -s code_lock_state demo -s init stop

run_handle_event: compile
	erl -noshell -s code_lock_handle_event demo -s init stop

run_common: compile
	erl -noshell -s code_lock_common demo -s init stop

run_stop: compile
	erl -noshell -s code_lock_stop demo -s init stop

run_event_timeout: compile
	erl -noshell -s code_lock_event_timeout demo -s init stop

run_generic_timeout: compile
	erl -noshell -s code_lock_generic_timeout demo -s init stop

run_erlang_timer: compile
	erl -noshell -s code_lock_erlang_timer demo -s init stop

run_postpone: compile
	erl -noshell -s code_lock_postpone demo -s init stop

run_enter: compile
	erl -noshell -s code_lock_enter demo -s init stop

run_inserted: compile
	erl -noshell -s code_lock_inserted demo -s init stop

run_complex: compile
	erl -noshell -s code_lock_complex demo -s init stop

run_selective: compile
	erl -noshell -s code_lock_selective demo -s init stop

run_all: compile
	@echo "=========================================="
	@echo "  Running all gen_statem demos"
	@echo "=========================================="
	erl -noshell \
		-s code_lock_state demo \
		-s code_lock_handle_event demo \
		-s code_lock_common demo \
		-s code_lock_stop demo \
		-s code_lock_event_timeout demo \
		-s code_lock_generic_timeout demo \
		-s code_lock_erlang_timer demo \
		-s code_lock_postpone demo \
		-s code_lock_enter demo \
		-s code_lock_inserted demo \
		-s code_lock_complex demo \
		-s code_lock_selective demo \
		-s init stop

clean:
	rm -f *.beam erl_crash.dump

help:
	@echo "Available targets:"
	@echo "  make compile           - Compile all .erl files"
	@echo "  make run_state         - Basic state_functions demo"
	@echo "  make run_handle_event  - handle_event_function demo"
	@echo "  make run_common        - All State Events demo"
	@echo "  make run_stop          - Stop demo"
	@echo "  make run_event_timeout - Event timeout demo"
	@echo "  make run_generic_timeout - Generic timeout demo"
	@echo "  make run_erlang_timer  - Erlang timer demo"
	@echo "  make run_postpone      - Postpone demo"
	@echo "  make run_enter         - State enter demo"
	@echo "  make run_inserted      - Inserted events (down/up) demo"
	@echo "  make run_complex       - Complex state demo"
	@echo "  make run_selective     - Selective receive demo"
	@echo "  make run_all           - Run all demos sequentially"
	@echo "  make clean             - Remove compiled files"
