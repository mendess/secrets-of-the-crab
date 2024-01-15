compile:
	pandoc \
	--standalone \
	-t revealjs \
	-o index.html \
	--slide-level=2 \
	presentation.md \
	-V revealjs-url=./reveal.js \
	-V theme=solarized

auto:
	touch index.html
	echo index.html | entr refresh_firefox &
	find *md ./reveal.js/ makefile | entr make
