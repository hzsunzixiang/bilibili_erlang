.PHONY: all pdf pdf-api clean distclean help view view-api draft draft-api stats

# Default target: build all PDFs
all: pdf pdf-api

# ============================================================
# PDF Generation (requires XeLaTeX from TeX Live)
# ============================================================
TEX = xelatex
TEXFLAGS = -interaction=nonstopmode -halt-on-error

# Tutorial document
SRC = gen_server_tutorial.tex
PDF = gen_server_tutorial.pdf

# API guide document
SRC_API = gen_server_api_guide.tex
PDF_API = gen_server_api_guide.pdf

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

pdf-api: $(PDF_API)

$(PDF_API): $(SRC_API)
	@which $(TEX) > /dev/null 2>&1 || \
		(echo "Error: $(TEX) not found. Install with: brew install --cask mactex" && exit 1)
	@echo "=== Compiling $(SRC_API) (pass 1/2) ==="
	$(TEX) $(TEXFLAGS) $(SRC_API)
	@echo "=== Compiling $(SRC_API) (pass 2/2 for TOC) ==="
	$(TEX) $(TEXFLAGS) $(SRC_API)
	@echo "=== Done: $(PDF_API) ==="
	@$(MAKE) clean

# Single pass (faster, for drafts)
draft:
	$(TEX) $(TEXFLAGS) $(SRC)

draft-api:
	$(TEX) $(TEXFLAGS) $(SRC_API)

# View the PDFs
view: pdf
	@if [ -f $(PDF) ]; then \
		open $(PDF); \
	else \
		echo "PDF not found. Run 'make pdf' first."; \
	fi

view-api: pdf-api
	@if [ -f $(PDF_API) ]; then \
		open $(PDF_API); \
	else \
		echo "PDF not found. Run 'make pdf-api' first."; \
	fi

# Word count and stats
stats:
	@echo "=== Document Statistics ==="
	@wc -l $(SRC) | awk '{print "Lines (tutorial): " $$1}'
	@wc -l $(SRC_API) | awk '{print "Lines (api guide): " $$1}'
	@if [ -f $(PDF) ]; then \
		ls -lh $(PDF) | awk '{print "PDF size (tutorial):  " $$5}'; \
	fi
	@if [ -f $(PDF_API) ]; then \
		ls -lh $(PDF_API) | awk '{print "PDF size (api guide): " $$5}'; \
	fi

# Clean intermediate files (keep PDFs)
clean:
	rm -f gen_server_tutorial.aux gen_server_tutorial.log
	rm -f gen_server_tutorial.out gen_server_tutorial.toc
	rm -f gen_server_tutorial.nav gen_server_tutorial.snm
	rm -f gen_server_tutorial.fdb_latexmk gen_server_tutorial.fls
	rm -f gen_server_tutorial.synctex.gz
	rm -f gen_server_api_guide.aux gen_server_api_guide.log
	rm -f gen_server_api_guide.out gen_server_api_guide.toc
	rm -f gen_server_api_guide.nav gen_server_api_guide.snm
	rm -f gen_server_api_guide.fdb_latexmk gen_server_api_guide.fls
	rm -f gen_server_api_guide.synctex.gz

# Clean everything including PDFs
distclean: clean
	rm -f gen_server_tutorial.pdf
	rm -f gen_server_api_guide.pdf

help:
	@echo "Available targets:"
	@echo "  make            - Build all PDFs (default)"
	@echo "  make pdf        - Build tutorial PDF"
	@echo "  make pdf-api    - Build API guide PDF"
	@echo "  make draft      - Quick single-pass tutorial PDF"
	@echo "  make draft-api  - Quick single-pass API guide PDF"
	@echo "  make view       - Build and open tutorial PDF"
	@echo "  make view-api   - Build and open API guide PDF"
	@echo "  make stats      - Show document statistics"
	@echo "  make clean      - Remove intermediate files (keep PDFs)"
	@echo "  make distclean  - Remove all generated files including PDFs"
