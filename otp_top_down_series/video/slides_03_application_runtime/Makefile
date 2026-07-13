# OTP Top-Down Series - Episode Makefile

all: presentation.pdf

presentation.pdf: presentation.tex
	latexmk -f -xelatex -interaction=nonstopmode presentation.tex
	latexmk -c
	rm -f presentation.nav presentation.snm

clean:
	latexmk -C 2>/dev/null || true
	rm -f presentation.nav presentation.snm

distclean: clean
	rm -f presentation.pdf

.PHONY: all clean distclean
