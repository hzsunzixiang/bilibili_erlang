.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

ERL = erl -boot start_clean

MODS := $(patsubst %.erl,%, $(wildcard *.erl))

.PHONY: all compile clean run_logger run_counter run_multi run_swap run_alarm run_sup run_all help

all: compile

compile: ${MODS:%=%.beam}

run_logger: compile
	erl -noshell -s event_logger demo -s init stop

run_counter: compile
	erl -noshell -s event_counter demo -s init stop

run_multi: compile
	erl -noshell -s multi_handler_demo demo -s init stop

run_swap: compile
	erl -noshell -s swap_handler_demo demo -s init stop

run_alarm: compile
	erl -noshell -s alarm_system demo -s init stop

run_sup: compile
	erl -noshell -s sup_handler_demo demo -s init stop

run_all: compile
	@echo "=========================================="
	@echo "  Running all gen_event demos"
	@echo "=========================================="
	erl -noshell \
		-s event_logger demo \
		-s event_counter demo \
		-s multi_handler_demo demo \
		-s swap_handler_demo demo \
		-s alarm_system demo \
		-s sup_handler_demo demo \
		-s init stop

clean:
	rm -f *.beam erl_crash.dump *.log events.log

help:
	@echo "Available targets:"
	@echo "  make compile    - Compile all .erl files"
	@echo "  make run_logger - Event logger demo (basic usage)"
	@echo "  make run_counter- Event counter demo (ETS + handle_call)"
	@echo "  make run_multi  - Multiple handlers demo"
	@echo "  make run_swap   - Swap handler demo (hot-swap)"
	@echo "  make run_alarm  - Alarm system demo (practical example)"
	@echo "  make run_sup    - Supervised handler demo (add_sup_handler)"
	@echo "  make run_all    - Run all demos sequentially"
	@echo "  make clean      - Remove compiled files"
