# Makefile for gen_event architecture diagrams
# Compile standalone TikZ diagrams to PDF

LATEX = xelatex
LATEXFLAGS = -interaction=nonstopmode -halt-on-error

SOURCES = gen_event_architecture_pid.tex

PDFS = $(SOURCES:.tex=.pdf)

.PHONY: all clean distclean

all: $(PDFS)

%.pdf: %.tex
	$(LATEX) $(LATEXFLAGS) $<
	@rm -f $*.aux $*.log $*.out

clean:
	rm -f *.aux *.log *.out *.synctex.gz

distclean: clean
	rm -f *.pdf
