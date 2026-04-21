.PHONY: all clean distclean view help

# ============================================================
# Architecture Diagram Build (standalone TikZ → PDF)
# ============================================================
TEX = xelatex
TEXFLAGS = -interaction=nonstopmode -halt-on-error

# Diagram sources
ARCH_SRC = application_architecture.tex
ARCH_PDF = application_architecture.pdf

# Default: build all diagrams
all: $(ARCH_PDF)

$(ARCH_PDF): $(ARCH_SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(ARCH_SRC) ==="
	$(TEX) $(TEXFLAGS) $(ARCH_SRC)
	@echo "=== Done: $(ARCH_PDF) ==="
	@$(MAKE) clean

# View the PDFs
view: $(ARCH_PDF)
	@open $(ARCH_PDF)

# Clean intermediate files (keep PDFs)
clean:
	rm -f *.aux *.log *.out *.toc *.nav *.snm
	rm -f *.xdv *.fdb_latexmk *.fls *.synctex.gz

# Clean everything including PDFs
distclean: clean
	rm -f *.pdf

help:
	@echo "Available targets:"
	@echo "  make        - Build application architecture diagram PDF (default)"
	@echo "  make view   - Build and open the architecture diagram"
	@echo "  make clean  - Remove intermediate files (keep PDFs)"
	@echo "  make distclean - Remove all generated files"
