# observer/Makefile — compile observer_tutorial.pdf
# Pattern follows wikipedia_storage/storage_full/Makefile: generate dependencies first,
# then build the master TeX document with latexmk + xelatex.
#
# Usage:
#   make           — regenerate observer_tutorial_body.tex and build PDF
#   make tex       — regenerate observer_tutorial_body.tex only
#   make clean     — remove intermediate files
#   make distclean — remove all generated files including PDF/body TeX

MASTER = observer_tutorial
MD = observer_tutorial.md
BODY = observer_tutorial_body.tex

.PHONY: all tex clean distclean

all: $(BODY)
	latexmk -f -xelatex -interaction=nonstopmode $(MASTER).tex
	latexmk -c
	@echo "==== Done: $(MASTER).pdf ===="

tex: $(BODY)

$(BODY): $(MD)
	pandoc -f markdown -t latex $(MD) -o $(BODY)

clean:
	latexmk -C 2>/dev/null || true

# Keep the hand-written master TeX file; remove only generated artifacts.
distclean: clean
	rm -f $(MASTER).pdf $(BODY)
