.PHONY: all clean help

# ============================================================
# Erlang Compilation
# ============================================================
ERLC = erlc
ERLCFLAGS = -Wall

# Source files
SRCS = $(wildcard *.erl)
BEAMS = $(SRCS:.erl=.beam)

# Default: compile all
all: $(BEAMS)

%.beam: %.erl
	$(ERLC) $(ERLCFLAGS) $<

# Clean compiled files
clean:
	rm -f *.beam erl_crash.dump

help:
	@echo "Available targets:"
	@echo "  make       - Compile all .erl files"
	@echo "  make clean - Remove .beam files and crash dumps"
