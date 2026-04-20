# Makefile for gen_event architecture diagrams
# Compile standalone TikZ diagrams to PDF

LATEX = xelatex
LATEXFLAGS = -interaction=nonstopmode -halt-on-error

SOURCES = gen_event_architecture_pid.tex gen_event_architecture_named.tex

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
