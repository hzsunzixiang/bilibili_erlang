.PHONY: all pdf clean distclean help view draft stats

# Default target: build PDF
all: pdf

# ============================================================
# PDF Generation (requires XeLaTeX from TeX Live)
# ============================================================
TEX = xelatex
TEXFLAGS = -interaction=nonstopmode -halt-on-error
SRC = gen_server_tutorial.tex
PDF = gen_server_tutorial.pdf

pdf: $(PDF)

$(PDF): $(SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(SRC) (pass 1/2) ==="
	$(TEX) $(TEXFLAGS) $(SRC)
	@echo "=== Compiling $(SRC) (pass 2/2 for TOC) ==="
	$(TEX) $(TEXFLAGS) $(SRC)
	@echo "=== Done: $(PDF) ==="

# Single pass (faster, for drafts)
draft:
	$(TEX) $(TEXFLAGS) $(SRC)

# View the PDF
view: pdf
	@if [ -f $(PDF) ]; then \
		open $(PDF); \
	else \
		echo "PDF not found. Run 'make pdf' first."; \
	fi

# Word count and stats
stats:
	@echo "=== Document Statistics ==="
	@wc -l gen_server_tutorial.tex | awk '{print "Lines (tex): " $$1}'
	@if [ -f $(PDF) ]; then \
		ls -lh $(PDF) | awk '{print "PDF size:    " $$5}'; \
	fi

# Clean intermediate files (keep PDF)
clean:
	rm -f gen_server_tutorial.aux gen_server_tutorial.log
	rm -f gen_server_tutorial.out gen_server_tutorial.toc
	rm -f gen_server_tutorial.nav gen_server_tutorial.snm
	rm -f gen_server_tutorial.fdb_latexmk gen_server_tutorial.fls
	rm -f gen_server_tutorial.synctex.gz

# Clean everything including PDF
distclean: clean
	rm -f gen_server_tutorial.pdf

help:
	@echo "Available targets:"
	@echo "  make          - Build PDF from LaTeX (default)"
	@echo "  make pdf      - Build PDF from LaTeX (requires xelatex)"
	@echo "  make draft    - Quick single-pass PDF (no TOC update)"
	@echo "  make view     - Build and open PDF"
	@echo "  make stats    - Show document statistics"
	@echo "  make clean     - Remove intermediate files (keep PDF)"
	@echo "  make distclean - Remove all generated files including PDF"
