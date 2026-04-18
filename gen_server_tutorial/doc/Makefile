.PHONY: all pdf clean help view stats

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

# ============================================================
# HTML Generation (optional, requires pandoc)
# ============================================================
html: gen_server_tutorial.html

gen_server_tutorial.html: gen_server_tutorial.md
	@which pandoc > /dev/null 2>&1 && \
		pandoc -f markdown -t html5 \
			--standalone \
			--toc \
			--toc-depth=3 \
			--metadata title="gen_server 完全教程" \
			--css=style.css \
			-o $@ $< && \
		echo "Generated $@" || \
		echo "pandoc not found. Install with: brew install pandoc"

# View markdown directly (requires glow or bat)
view_md:
	@which glow > /dev/null 2>&1 && glow gen_server_tutorial.md || \
	 which bat > /dev/null 2>&1 && bat gen_server_tutorial.md || \
	 cat gen_server_tutorial.md

# Word count and stats
stats:
	@echo "=== Document Statistics ==="
	@wc -l gen_server_tutorial.tex | awk '{print "Lines (tex): " $$1}'
	@wc -l gen_server_tutorial.md  | awk '{print "Lines (md):  " $$1}'
	@if [ -f $(PDF) ]; then \
		ls -lh $(PDF) | awk '{print "PDF size:    " $$5}'; \
	fi

# Clean all generated files
clean:
	rm -f gen_server_tutorial.pdf gen_server_tutorial.html
	rm -f gen_server_tutorial.aux gen_server_tutorial.log
	rm -f gen_server_tutorial.out gen_server_tutorial.toc
	rm -f gen_server_tutorial.nav gen_server_tutorial.snm
	rm -f gen_server_tutorial.fdb_latexmk gen_server_tutorial.fls
	rm -f gen_server_tutorial.synctex.gz

help:
	@echo "Available targets:"
	@echo "  make          - Build PDF from LaTeX (default)"
	@echo "  make pdf      - Build PDF from LaTeX (requires xelatex)"
	@echo "  make draft    - Quick single-pass PDF (no TOC update)"
	@echo "  make view     - Build and open PDF"
	@echo "  make html     - Generate HTML from Markdown (requires pandoc)"
	@echo "  make view_md  - View Markdown in terminal"
	@echo "  make stats    - Show document statistics"
	@echo "  make clean    - Remove all generated files"
