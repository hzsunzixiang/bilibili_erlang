# Makefile for gen_event architecture diagrams
# Compile standalone TikZ diagrams to PDF

LATEX = xelatex
LATEXFLAGS = -interaction=nonstopmode -halt-on-error

SOURCES = gen_event_architecture.tex \
          gen_event_handler_lifecycle.tex \
          gen_event_vs_gen_server.tex

PDFS = $(SOURCES:.tex=.pdf)

.PHONY: all clean

all: $(PDFS)

%.pdf: %.tex
	$(LATEX) $(LATEXFLAGS) $<
	@rm -f $*.aux $*.log $*.out

clean:
	rm -f *.pdf *.aux *.log *.out *.synctex.gz
