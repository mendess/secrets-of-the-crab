compile:
	pandoc \
	--standalone \
	-t revealjs \
	-o index.html \
	--slide-level=2 \
	presentation.md \
	-V revealjs-url=./reveal.js \
	-V theme=black \
	--highlight-style ./gruvbox.theme

auto:
	touch index.html
	find *md ./reveal.js/ makefile | entr make
