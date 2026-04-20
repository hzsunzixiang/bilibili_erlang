.PHONY: all pdf clean distclean help view draft stats

# Default target: build PDF
all: pdf

# ============================================================
# PDF Generation (requires XeLaTeX from TeX Live)
# ============================================================
TEX = xelatex
TEXFLAGS = -interaction=nonstopmode -halt-on-error

SRC = erlang_knowledge_summary.tex
PDF = erlang_knowledge_summary.pdf

pdf: $(PDF)

$(PDF): $(SRC)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(SRC) (pass 1/2) ==="
	$(TEX) $(TEXFLAGS) $(SRC)
	@echo "=== Compiling $(SRC) (pass 2/2 for TOC) ==="
	$(TEX) $(TEXFLAGS) $(SRC)
	@echo "=== Done: $(PDF) ==="
	@$(MAKE) clean

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

# Document stats
stats:
	@echo "=== Document Statistics ==="
	@wc -l $(SRC) | awk '{print "Lines: " $$1}'
	@ls images/ | wc -l | awk '{print "Images: " $$1}'
	@if [ -f $(PDF) ]; then \
		ls -lh $(PDF) | awk '{print "PDF size: " $$5}'; \
	fi

# Clean intermediate files (keep PDFs)
clean:
	rm -f *.aux *.log *.out *.toc *.nav *.snm
	rm -f *.xdv *.fdb_latexmk *.fls *.synctex.gz

# Clean everything including PDFs
distclean: clean
	rm -f $(PDF)

help:
	@echo "Available targets:"
	@echo "  make            - Build Erlang knowledge summary PDF (default)"
	@echo "  make pdf        - Build Erlang knowledge summary PDF"
	@echo "  make draft      - Quick single-pass PDF"
	@echo "  make view       - Build and open PDF"
	@echo "  make stats      - Show document statistics"
	@echo "  make clean      - Remove intermediate files (keep PDFs)"
	@echo "  make distclean  - Remove all generated files including PDFs"
