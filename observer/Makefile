# observer/Makefile — compile observer_tutorial.pdf
# Pattern follows wikipedia_storage/storage_full/Makefile: build the master TeX
# document with latexmk + xelatex.
#
# Usage:
#   make           — build PDF from observer_tutorial.tex and observer_tutorial_body.tex
#   make clean     — remove intermediate files
#   make distclean — remove generated PDF only

MASTER = observer_tutorial
BODY = observer_tutorial_body.tex

.PHONY: all clean distclean

all: $(BODY)
	latexmk -f -xelatex -interaction=nonstopmode $(MASTER).tex
	latexmk -c
	@echo "==== Done: $(MASTER).pdf ===="

clean:
	latexmk -C 2>/dev/null || true

# Keep the hand-written TeX files; remove only generated PDF artifacts.
distclean: clean
	rm -f $(MASTER).pdf
