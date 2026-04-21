.PHONY: all clean help

# ============================================================
# Recursive build for sub-applications
# ============================================================
SUBDIRS = simple_app phased_app

# Default: compile all sub-applications
all:
	@for dir in $(SUBDIRS); do \
		echo "=== Building $$dir ==="; \
		$(MAKE) -C $$dir all; \
	done

# Clean all sub-applications
clean:
	@for dir in $(SUBDIRS); do \
		echo "=== Cleaning $$dir ==="; \
		$(MAKE) -C $$dir clean; \
	done

help:
	@echo "Available targets:"
	@echo "  make       - Compile all sub-applications (simple_app, phased_app)"
	@echo "  make clean - Clean all sub-applications"
	@echo ""
	@echo "To build/run individually:"
	@echo "  cd simple_app && make run"
	@echo "  cd phased_app && make run"
