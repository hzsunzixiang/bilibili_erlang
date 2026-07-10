# Observer Video Series - Top-level Makefile
# Builds all episode PDFs and merges them into one combined PDF
#
# Usage:
#   make            - Build all episodes and merge into one PDF
#   make build      - Build all episode PDFs (without merging)
#   make merge      - Merge existing PDFs (assumes already built)
#   make clean      - Clean all subdirectories
#   make distclean  - Remove all generated PDFs

SHELL := /bin/bash

# Tools
PDFUNITE := pdfunite

# Subdirectories in order
SUBDIRS := \
	slides_01_observer_ui \
	slides_02_observer_cli

# Generated files
PDFS := $(foreach dir,$(SUBDIRS),$(dir)/presentation.pdf)
MERGED := observer_full_series.pdf

# ============================================================
# Default target
# ============================================================
.PHONY: all build merge clean distclean rebuild

all: build merge

# ============================================================
# Build: compile each subdirectory
# ============================================================
build:
	@for dir in $(SUBDIRS); do \
		echo "=== Building $$dir ==="; \
		$(MAKE) -C $$dir all || exit 1; \
	done

# ============================================================
# Merge: combine all PDFs into one
# ============================================================
merge: $(MERGED)

$(MERGED):
	@echo "=== Merging all episodes into $(MERGED) ==="
	$(PDFUNITE) $(PDFS) $(MERGED)
	@echo "=== Done: $(MERGED) ==="

# ============================================================
# Clean
# ============================================================
clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done

distclean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir distclean; \
	done
	rm -f $(MERGED)

rebuild: distclean all
