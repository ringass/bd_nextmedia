# Configuração de build do projeto NextMedia
# Mantém a raiz limpa: todos os arquivos intermediários vão para build/,
# apenas o PDF final (e o synctex) fica no diretório do projeto.

$pdf_mode = 1;          # compila com pdflatex
$bibtex_use = 2;        # roda bibtex e limpa o .bbl no clean

$aux_dir = 'build';     # .aux .log .toc .out .bbl .blg .fls .fdb_latexmk
$out_dir = '.';         # nextmedia.pdf

$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';

# Arquivos extras que o clean deve remover
$clean_ext = 'synctex.gz run.xml bbl';
