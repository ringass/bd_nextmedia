# Configuração de build do projeto NextMedia
# Mantém a raiz limpa: todos os arquivos intermediários vão para build/,
# apenas o PDF final (e o synctex) fica no diretório do projeto.

$pdf_mode = 1;          # compila com pdflatex
$bibtex_use = 2;        # roda bibtex e limpa o .bbl no clean

$aux_dir = 'build';     # .aux .log .toc .out .bbl .blg .fls .fdb_latexmk
$out_dir = '.';         # nextmedia.pdf

# Por causa do $aux_dir acima, o latexmk entra em build/ antes de chamar o
# bibtex. De la o refs.bib da raiz fica invisivel, e o efeito e silencioso:
# as citacoes saem como [?] e a secao de Referencias vem vazia. BIBINPUTS
# manda o kpathsea procurar tambem um nivel acima. O separador terminal
# preserva os caminhos padrao do sistema.
my $sep = ($^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin') ? ';' : ':';
$ENV{'BIBINPUTS'} = defined $ENV{'BIBINPUTS'} && $ENV{'BIBINPUTS'} ne ''
                  ? '..' . $sep . $ENV{'BIBINPUTS'}
                  : '..' . $sep;

$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 %O %S';

# Arquivos extras que o clean deve remover
$clean_ext = 'synctex.gz run.xml bbl';
