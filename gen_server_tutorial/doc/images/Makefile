.PHONY: all clean distclean view help

# ============================================================
# Architecture Diagram Build (standalone TikZ → PDF)
# ============================================================
TEX = xelatex
TEXFLAGS = -interaction=nonstopmode -halt-on-error

# Diagram sources
ARCH_PID_SRC   = gen_server_architecture_pid.tex
ARCH_PID_PDF   = gen_server_architecture_pid.pdf
ARCH_NAMED_SRC = gen_server_architecture_named.tex
ARCH_NAMED_PDF = gen_server_architecture_named.pdf

# Default: build all diagrams
all: $(ARCH_PID_PDF) $(ARCH_NAMED_PDF)

$(ARCH_PID_PDF): $(ARCH_PID_SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(ARCH_PID_SRC) ==="
	$(TEX) $(TEXFLAGS) $(ARCH_PID_SRC)
	@echo "=== Done: $(ARCH_PID_PDF) ==="
	@$(MAKE) clean

$(ARCH_NAMED_PDF): $(ARCH_NAMED_SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(ARCH_NAMED_SRC) ==="
	$(TEX) $(TEXFLAGS) $(ARCH_NAMED_SRC)
	@echo "=== Done: $(ARCH_NAMED_PDF) ==="
	@$(MAKE) clean

# View the PDFs
view: $(ARCH_PID_PDF) $(ARCH_NAMED_PDF)
	@open $(ARCH_PID_PDF)
	@open $(ARCH_NAMED_PDF)

# Clean intermediate files (keep PDFs)
clean:
	rm -f *.aux *.log *.out *.toc *.nav *.snm
	rm -f *.xdv *.fdb_latexmk *.fls *.synctex.gz

# Clean everything including PDFs
distclean: clean
	rm -f *.pdf

help:
	@echo "Available targets:"
	@echo "  make        - Build all architecture diagram PDFs (default)"
	@echo "  make view   - Build and open all architecture diagrams"
	@echo "  make clean  - Remove intermediate files (keep PDFs)"
	@echo "  make distclean - Remove all generated files"
