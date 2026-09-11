# Build do relatório NextMedia
# Todos os arquivos intermediários vão para build/ (ver .latexmkrc);
# na raiz fica apenas nextmedia.pdf.

DOC = nextmedia

.PHONY: all clean distclean watch

all:
	latexmk $(DOC).tex

# Remove os intermediários, mantém o PDF
clean:
	latexmk -c $(DOC).tex

# Remove os intermediários e o PDF
distclean:
	latexmk -C $(DOC).tex
	rm -rf build

# Recompila automaticamente a cada alteração
watch:
	latexmk -pvc $(DOC).tex
