.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

ERL = erl -boot start_clean

MODS := $(patsubst %.erl,%, $(wildcard *.erl))

.PHONY: all compile clean run_raw run_generic run_otp run_reply run_timeout run_call_timeout run_kv_local run_kv_global run_kv_unnamed run_distributed help

all: compile

compile: ${MODS:%=%.beam}

## Run individual demos
run_raw: compile
	erl -noshell -s frequency_raw demo -s init stop

run_generic: compile
	erl -noshell -s frequency_generic demo -s init stop

run_otp: compile
	erl -noshell -s frequency_otp demo -s init stop

run_reply: compile
	erl -noshell -s frequency_reply demo -s init stop

run_timeout: compile
	erl -noshell -s timeout_demo demo -s init stop

run_call_timeout: compile
	erl -noshell -s call_timeout_demo demo -s init stop

run_kv_local: compile
	erl -noshell -s kv_store demo_local -s init stop

run_kv_global: compile
	erl -noshell -s kv_store demo_global -s init stop

run_kv_unnamed: compile
	erl -noshell -s kv_store demo_unnamed -s init stop

run_distributed: compile
	erl -noshell -s distributed_demo demo_local -s init stop

## Run all demos in sequence
run_all: compile
	@echo "=========================================="
	@echo "  Running ALL gen_server demos"
	@echo "=========================================="
	@echo ""
	@echo ">>> Step 1: Raw frequency server"
	erl -noshell -s frequency_raw demo -s init stop
	@echo ""
	@echo ">>> Step 2: Generic server abstraction"
	erl -noshell -s frequency_generic demo -s init stop
	@echo ""
	@echo ">>> Step 3: OTP gen_server"
	erl -noshell -s frequency_otp demo -s init stop
	@echo ""
	@echo ">>> Explicit reply demo"
	erl -noshell -s frequency_reply demo -s init stop
	@echo ""
	@echo ">>> Call timeout demo"
	erl -noshell -s call_timeout_demo demo -s init stop
	@echo ""
	@echo ">>> KV Store - Local"
	erl -noshell -s kv_store demo_local -s init stop
	@echo ""
	@echo ">>> KV Store - Unnamed"
	erl -noshell -s kv_store demo_unnamed -s init stop
	@echo ""
	@echo ">>> Distributed demo (local)"
	erl -noshell -s distributed_demo demo_local -s init stop
	@echo ""
	@echo "=========================================="
	@echo "  All demos completed!"
	@echo "=========================================="

clean:
	rm -f *.beam erl_crash.dump

help:
	@echo "Available targets:"
	@echo "  make compile        - Compile all .erl files"
	@echo "  make run_raw        - Step 1: Raw frequency server"
	@echo "  make run_generic    - Step 2: Generic server abstraction"
	@echo "  make run_otp        - Step 3: OTP gen_server"
	@echo "  make run_reply      - Explicit reply demo"
	@echo "  make run_timeout    - Timeout demo (takes ~15s)"
	@echo "  make run_call_timeout - Call timeout demo"
	@echo "  make run_kv_local   - KV Store local registration"
	@echo "  make run_kv_global  - KV Store global registration"
	@echo "  make run_kv_unnamed - KV Store unnamed (by PID)"
	@echo "  make run_distributed - Distributed demo (local)"
	@echo "  make run_all        - Run all demos"
	@echo "  make clean          - Remove compiled files"
