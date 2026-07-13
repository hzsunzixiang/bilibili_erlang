# tikz/Makefile — Build standalone TikZ diagrams for preview
#
# Usage:
#   make                    — build all TikZ PDFs
#   make clean              — remove build artifacts
#   make distclean          — remove generated PDFs
#
# Architecture:
#   *-body.tex       — shared TikZ source (single source of truth)
#   *-standalone.tex — standalone wrapper (preamble + \input{body})

BODY_TEX = $(wildcard *-body.tex)
STANDALONE_TEX = $(BODY_TEX:-body.tex=-standalone.tex)
TIKZ_PDF = $(BODY_TEX:-body.tex=-standalone.pdf)

CLEAN_EXTS = *.aux *.log *.fls *.fdb_latexmk *.xdv *.synctex.gz

all: $(TIKZ_PDF)

# Compile standalone wrapper — output PDF matches the .tex filename
%-standalone.pdf: %-standalone.tex %-body.tex
	latexmk -f -xelatex -interaction=nonstopmode $*-standalone.tex
	@rm -f $(CLEAN_EXTS)

clean:
	rm -f $(CLEAN_EXTS)

distclean: clean
	rm -f $(TIKZ_PDF)

.PHONY: all clean distclean
