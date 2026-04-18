.PHONY: all html pdf clean help

# Default target
all: html

# Generate HTML from Markdown (requires pandoc)
html: gen_server_tutorial.html

gen_server_tutorial.html: gen_server_tutorial.md
	@which pandoc > /dev/null 2>&1 && \
		pandoc -f markdown -t html5 \
			--standalone \
			--toc \
			--toc-depth=3 \
			--metadata title="gen_server 完全教程" \
			--css=style.css \
			-o $@ $< && \
		echo "Generated $@" || \
		echo "pandoc not found. Install with: brew install pandoc"

# View the document
view: html
	@if [ -f gen_server_tutorial.html ]; then \
		open gen_server_tutorial.html; \
	else \
		echo "HTML file not found. Run 'make html' first."; \
	fi

# View markdown directly (requires glow or bat)
view_md:
	@which glow > /dev/null 2>&1 && glow gen_server_tutorial.md || \
	 which bat > /dev/null 2>&1 && bat gen_server_tutorial.md || \
	 cat gen_server_tutorial.md

# Word count and stats
stats:
	@echo "=== Document Statistics ==="
	@wc -l gen_server_tutorial.md | awk '{print "Lines: " $$1}'
	@wc -w gen_server_tutorial.md | awk '{print "Words: " $$1}'
	@wc -c gen_server_tutorial.md | awk '{print "Bytes: " $$1}'
	@grep -c '```' gen_server_tutorial.md | awk '{print "Code blocks: " $$1/2}'
	@grep -c '^##' gen_server_tutorial.md | awk '{print "Sections: " $$1}'

clean:
	rm -f gen_server_tutorial.html

help:
	@echo "Available targets:"
	@echo "  make html     - Generate HTML from Markdown (requires pandoc)"
	@echo "  make view     - Generate and open HTML in browser"
	@echo "  make view_md  - View Markdown in terminal (requires glow or bat)"
	@echo "  make stats    - Show document statistics"
	@echo "  make clean    - Remove generated files"
