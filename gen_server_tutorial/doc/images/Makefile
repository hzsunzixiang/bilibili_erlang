.PHONY: all clean distclean view help

# ============================================================
# Architecture Diagram Build (standalone TikZ → PDF)
# ============================================================
TEX = xelatex
TEXFLAGS = -interaction=nonstopmode -halt-on-error

# All diagram sources
ARCH_SRC = gen_server_architecture.tex
ARCH_PDF = gen_server_architecture.pdf

STARTUP_SRC = gen_server_startup.tex
STARTUP_PDF = gen_server_startup.pdf

ARCH_PID_SRC = gen_server_architecture_pid.tex
ARCH_PID_PDF = gen_server_architecture_pid.pdf

# Default: build all diagrams
all: $(ARCH_PDF) $(STARTUP_PDF) $(ARCH_PID_PDF)

$(ARCH_PDF): $(ARCH_SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(ARCH_SRC) ==="
	$(TEX) $(TEXFLAGS) $(ARCH_SRC)
	@echo "=== Done: $(ARCH_PDF) ==="
	@$(MAKE) clean

$(STARTUP_PDF): $(STARTUP_SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(STARTUP_SRC) ==="
	$(TEX) $(TEXFLAGS) $(STARTUP_SRC)
	@echo "=== Done: $(STARTUP_PDF) ==="
	@$(MAKE) clean

$(ARCH_PID_PDF): $(ARCH_PID_SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(ARCH_PID_SRC) ==="
	$(TEX) $(TEXFLAGS) $(ARCH_PID_SRC)
	@echo "=== Done: $(ARCH_PID_PDF) ==="
	@$(MAKE) clean

# View the PDF
view: $(ARCH_PDF)
	@open $(ARCH_PDF)

# Clean intermediate files (keep PDFs)
clean:
	rm -f *.aux *.log *.out *.toc *.nav *.snm
	rm -f *.fdb_latexmk *.fls *.synctex.gz

# Clean everything including PDFs
distclean: clean
	rm -f *.pdf

help:
	@echo "Available targets:"
	@echo "  make        - Build all diagram PDFs (default)"
	@echo "  make view   - Build and open architecture diagram"
	@echo "  make clean  - Remove intermediate files (keep PDFs)"
	@echo "  make distclean - Remove all generated files"
