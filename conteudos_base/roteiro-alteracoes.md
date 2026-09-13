# Roteiro de alterações — alinhar o texto ao DER conceitual final

Contexto: o DER conceitual da NextMedia foi finalizado no brModelo e exportado
para `images/DER-conceitual.png`. Este roteiro lista as alterações necessárias
no texto LaTeX e no script SQL para que documento, diagrama e implementação
digam a mesma coisa.

Execute as alterações na ordem. Cada item traz o texto atual e o texto novo.
Onde o texto atual for longo, ele está citado apenas o suficiente para
localizar o trecho.

---

## 1. Seção 2.1 — `participacao` é relacionamento, não entidade

**Problema:** o texto conta treze entidades e inclui `participacao` na lista.
No diagrama final ela é um losango com três atributos próprios (`papel`,
`personagem`, `ordem_credito`), coerente com o que o Capítulo 1 já afirma —
"um relacionamento N:N que carrega atributos próprios". A lista precisa
acompanhar.

### 1.1 — Trocar a contagem

Localizar:

> O relato se traduz em treze entidades, agrupadas em quatro núcleos — assinatura, catálogo, pessoas e consumo:

Substituir por:

> O relato se traduz em doze entidades, agrupadas em quatro núcleos — assinatura, catálogo, pessoas e consumo:

### 1.2 — Remover `participacao` da lista de entidades

Localizar e **excluir** o item:

> • participacao — atuação de uma pessoa em um título, com papel e personagem.

### 1.3 — Ampliar o parágrafo que trata do que ficou fora da contagem

Localizar o parágrafo que começa com:

> A associação entre títulos e gêneros não entra nessa contagem:

Substituir o parágrafo inteiro por:

> Dois relacionamentos não entram nessa contagem, por motivos diferentes. A associação entre títulos e gêneros não guarda informação própria: um título tem vários gêneros e um gênero reúne vários títulos, mas o vínculo é só o par, e ele vira tabela no modelo lógico sem nunca ter sido entidade. Já a participação de uma pessoa em um título carrega atributos seus — o papel exercido, o personagem interpretado e a posição nos créditos —, e no diagrama aparece como relacionamento com atributos, não como retângulo. A distinção importa porque nada no minimundo se liga à participação: nenhuma entidade precisa referenciar uma atuação específica, que é a única situação que justificaria promovê-la a entidade associativa. Como todo relacionamento N:N, ela também vira tabela no Capítulo 3. Os atributos de cada entidade aparecem no diagrama da Seção 2.3 e no modelo lógico do Capítulo 3.

---

## 2. Seção 2.2 — corrigir a classificação de RN02 e RN13

**Problema:** a implementação mostrou que RN02 se resolve declarativamente
(índice único parcial sobre `data_fim IS NULL`) e que RN13 não se resolve
(a duração do conteúdo está em outra tabela, e um `CHECK` não a alcança).
O texto atual afirma o contrário nos dois casos.

### 2.1 — Parágrafo das regras declarativas

Localizar:

> Outras se resolvem com uma restrição declarada na criação da tabela — RN01 e RN08 são unicidade, RN11 vira a chave primária composta de participacao, RN12 e RN13 são verificações sobre a própria linha, e RN17 é a ação de propagação da chave estrangeira. Em ambos os casos o banco cuida sozinho, por qualquer caminho de escrita.

Substituir por:

> Outras se resolvem com uma restrição declarada na criação da tabela — RN01 e RN08 são unicidade, RN11 vira a chave primária composta de participacao, RN12 é verificação sobre a própria linha, e RN17 é a ação de propagação da chave estrangeira. RN02 também entra aqui, embora dependa das demais assinaturas da conta: como uma assinatura está ativa exatamente enquanto sua data de término é nula, um índice único parcial sobre as linhas nesse estado basta para garantir que só exista uma por conta. Em todos esses casos o banco cuida sozinho, por qualquer caminho de escrita.

### 2.2 — Parágrafo do grupo problemático

Localizar:

> O grupo problemático é outro: RN02, RN03, RN09 e RN10 dependem de informação que não está na linha gravada — as demais assinaturas da conta, o plano a duas tabelas de distância, um vínculo criado só depois do título, ou a árvore inteira de gêneros.

Substituir por:

> O grupo problemático é outro: RN03, RN09, RN10 e RN13 dependem de informação que não está na linha gravada — o plano a duas tabelas de distância, um vínculo criado só depois do título, a árvore inteira de gêneros, ou a duração do conteúdo assistido. RN13 é a menos evidente das quatro: parece verificação local, mas a duração mora em filme ou episódio, e uma verificação de linha não enxerga outra tabela.

---

## 3. Seção 2.3 — inserir o diagrama e o texto que o acompanha

**Problema:** a seção tem apenas o espaço reservado para a imagem.

Substituir o conteúdo inteiro da Seção 2.3 por:

> A Figura~\ref{fig:der-conceitual} apresenta o diagrama entidade-relacionamento da NextMedia, construído no brModelo segundo a notação de Chen. Os quatro núcleos da Seção 2.1 aparecem distribuídos no diagrama: assinatura no alto à esquerda, catálogo no centro e à direita, pessoas à esquerda do título, consumo na coluna inferior esquerda.
>
> Três construções merecem atenção na leitura. A especialização de título em filme e série está marcada com o discriminador de disjunção, indicando que os subtipos são mutuamente exclusivos; a totalidade, que o minimundo também exige, está enunciada na RN06 e discutida na Seção 3.3.1. Os dois auto-relacionamentos trazem os papéis escritos sobre cada ligação — pai e filho em subgênero de, origem e continuação em origina —, sem os quais não haveria como distinguir as duas pontas, já que ambas chegam na mesma entidade. E o relacionamento de participação carrega atributos próprios, desenhados junto ao losango.
>
> Nem tudo o que o minimundo exige cabe na notação. A exclusividade entre os dois relacionamentos de visualização — cada registro aponta para um filme ou para um episódio, nunca para ambos — não tem representação gráfica no modelo entidade-relacionamento, e o mesmo vale para a ausência de ciclos na hierarquia de gêneros. A legenda do diagrama reúne essas convenções, cada uma remetendo à regra que a enuncia, e o Capítulo 4 retoma uma a uma ao lado do mecanismo que as garante.

Acrescentar, ao fim do primeiro parágrafo, uma nota de rodapé:

> \footnote{As convenções que a notação de Chen não expressa graficamente — a distinção entre entidade forte e fraca no contorno, a totalidade da especialização, a exclusividade entre dois relacionamentos e a ausência de ciclos numa hierarquia — estão listadas na legenda do próprio diagrama, cada uma remetendo à regra de negócio correspondente.}

Atualizar o ambiente de figura para:

```latex
\begin{figure}[h]
    \centering
    \includegraphics[width=\textwidth]{images/DER-conceitual.png}
    \caption{Diagrama Entidade-Relacionamento da NextMedia.}
    \label{fig:der-conceitual}
\end{figure}
```

---

## 4. Nomenclatura das chaves parciais

**Problema:** o diagrama usa `num_temporada` e `num_episodio`; o script SQL e
os capítulos 3 e 4 usam `numero_temporada` e `numero_episodio`. Como o
diagrama está finalizado, a padronização segue o diagrama.

Em `sql/nextmedia.sql` e em todos os arquivos `.tex`, renomear:

- `numero_temporada` → `num_temporada`
- `numero_episodio` → `num_episodio`

Atenção: a renomeação atinge também as colunas de `visualizacao`, que
referenciam a chave tripla do episódio, e as restrições `ck_temporada_numero`,
`ck_episodio_numero`, `pk_temporada`, `pk_episodio`,
`fk_episodio_temporada` e `fk_visualizacao_episodio`. Os nomes das
constraints não mudam — apenas as colunas citadas dentro delas.

Após a renomeação, reexecutar o script num banco vazio para confirmar que
nada quebrou.

---

## 5. Capítulo 3 — ajustar a contagem de tabelas

Localizar, na Seção 3.1:

> O resultado são quatorze tabelas: as treze entidades do minimundo mais titulo_genero.

Substituir por:

> O resultado são quatorze tabelas: as doze entidades do minimundo mais titulo_genero e participacao, os dois relacionamentos que precisaram de tabela própria.

---

## 6. Verificação final

Depois de aplicar tudo, conferir que:

- nenhuma ocorrência de "treze entidades" restou no texto;
- RN02 não aparece mais descrita como problemática em nenhum capítulo;
- RN13 aparece como gatilho na Tabela 4.1 e no texto da Seção 4.3 (já está
  correto no Capítulo 4 — verificar que o Capítulo 2 agora concorda);
- o rótulo `fig:der-conceitual` é usado nas Seções 2.3 e 3.1;
- `grep -c numero_temporada` e `grep -c numero_episodio` retornam zero em
  todos os arquivos do projeto.
