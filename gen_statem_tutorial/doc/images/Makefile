# Makefile for gen_statem architecture diagrams
# Compile standalone TikZ diagrams to PDF

LATEX = xelatex
LATEXFLAGS = -interaction=nonstopmode -halt-on-error

SOURCES = gen_statem_architecture_pid.tex

PDFS = $(SOURCES:.tex=.pdf)

.PHONY: all clean distclean

all: $(PDFS)
	@$(MAKE) clean

%.pdf: %.tex
	$(LATEX) $(LATEXFLAGS) $<

clean:
	rm -f *.aux *.log *.out *.synctex.gz

distclean: clean
	rm -f *.pdf
