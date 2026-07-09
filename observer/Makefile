# observer/Makefile — compile Observer tutorial and Beamer PDFs
# Pattern follows wikipedia_storage/storage_full/Makefile: build TeX documents
# with latexmk + xelatex.
#
# Usage:
#   make           — build tutorial PDF and both Beamer PDFs
#   make tutorial  — build observer_tutorial.pdf
#   make beamer    — build observer_ui_beamer.pdf and observer_cli_beamer.pdf
#   make clean     — remove intermediate files
#   make distclean — remove generated PDFs only

MASTER = observer_tutorial
BODY = observer_tutorial_body.tex
BEAMERS = observer_ui_beamer observer_cli_beamer
PDFS = $(MASTER).pdf $(addsuffix .pdf,$(BEAMERS))

.PHONY: all tutorial beamer clean distclean

all: tutorial beamer

tutorial: $(MASTER).pdf

beamer: $(addsuffix .pdf,$(BEAMERS))

$(MASTER).pdf: $(MASTER).tex $(BODY)
	latexmk -f -xelatex -interaction=nonstopmode $(MASTER).tex
	latexmk -c
	@echo "==== Done: $(MASTER).pdf ===="

%.pdf: %.tex
	latexmk -f -xelatex -interaction=nonstopmode $<
	latexmk -c
	@echo "==== Done: $@ ===="

clean:
	latexmk -C 2>/dev/null || true

# Keep the hand-written TeX files; remove only generated PDF artifacts.
distclean: clean
	rm -f $(PDFS)
