# Briefing — Projeto de Banco de Dados I (NextMedia)

Documento de contexto para trabalho assistido no repositório LaTeX. Contém as decisões já fechadas pelo grupo, o que ainda está em aberto e as convenções a seguir. **Leia inteiro antes de editar qualquer `.tex`.**

---

## 1. O que é o trabalho

Disciplina de Banco de Dados I (UNESP/FC Bauru, prof. Bruno Elias Penteado). Entrega via Google Classroom, prazo **16/09**, grupos de 4 pessoas.

O entregável é **um documento com três partes**:

1. **Modelo conceitual** — explicação do minimundo, regras de negócio e DER.
2. **Modelo lógico** — diagrama lógico já normalizado, com justificativas das decisões.
3. **Modelo físico** — arquivo `.sql` comentado que cria o schema e as tabelas com todas as constraints.

O documento é escrito em LaTeX neste repositório. O `.sql` é arquivo separado, mas trechos dele podem aparecer no documento como listagens.

---

## 2. Decisões já fechadas

Estas decisões **não devem ser alteradas** sem falar com o grupo. Se algo no repositório contradisser esta lista, esta lista vence.

| Decisão | Valor |
|---|---|
| Domínio do minimundo | Plataforma de streaming de vídeo por assinatura |
| Nome do projeto | **NextMedia** |
| Nome do schema | `nextmedia` (minúsculo, sem separador) |
| SGBD | PostgreSQL (pgAdmin / ERD Tool) |
| Nº de entidades no núcleo | 13 (limite pedido: 10 a 15) |
| Idioma do documento | Português |
| Idioma dos identificadores SQL | Português, `snake_case`, singular (`titulo`, `item_lista`) |
| Mapeamento da especialização | Supertipo + subtipos compartilhando PK |

---

## 3. O minimundo em uma página

A **NextMedia** é um serviço de streaming por assinatura. Um cliente cria uma **conta**, escolhe um **plano** (preço mensal, máximo de telas simultâneas, máximo de perfis, qualidade de vídeo) e passa a ter uma **assinatura** vigente. Trocas de plano encerram a assinatura anterior e abrem uma nova, preservando o histórico.

Dentro de uma conta existem vários **perfis**, um por pessoa da casa, com nome, avatar, idioma preferido e marcação de perfil infantil (que restringe a classificação indicativa acessível).

O catálogo é composto por **títulos**, que são **filmes** ou **séries**. Séries se organizam em **temporadas**, que contêm **episódios**. Todo título tem um ou mais **gêneros**, e gêneros formam hierarquia (subgênero aponta para gênero-pai). Títulos também podem apontar para um título de origem, representando franquias e continuações.

**Pessoas** (atores, diretores, roteiristas) participam dos títulos, podendo acumular papéis no mesmo título.

Cada vez que um perfil assiste algo, registra-se uma **visualização** com início, tempo assistido, dispositivo e se foi concluído.

---

## 4. Entidades (13 no núcleo)

| # | Entidade | Papel no modelo |
|---|---|---|
| 1 | `conta` | Assinante, dados de acesso e cobrança |
| 2 | `plano` | Catálogo de planos comercializados |
| 3 | `assinatura` | Associativa `conta` × `plano` com temporalidade |
| 4 | `perfil` | Subusuário dentro da conta |
| 5 | `titulo` | Supertipo do catálogo; auto-relacionamento de franquia |
| 6 | `filme` | Subtipo de `titulo` |
| 7 | `serie` | Subtipo de `titulo` |
| 8 | `temporada` | Fraca, dependente de `serie` |
| 9 | `episodio` | Fraca, dependente de `temporada` |
| 10 | `genero` | Auto-relacionamento hierárquico |
| 11 | `pessoa` | Elenco e equipe técnica |
| 12 | `participacao` | Associativa `titulo` × `pessoa`, com papel |
| 13 | `visualizacao` | Histórico de consumo de `filme` ou `episodio` |

Relacionamento N:N sem atributos: `titulo_genero`. Vira tabela no lógico, mas **não conta como entidade** no conceitual.

**Opcionais**, caso o grupo decida expandir para 14 ou 15: `avaliacao`, `item_lista`, `pagamento`, `dispositivo`. Hoje estão fora do escopo — só entram por decisão explícita.

---

## 5. Regras de negócio

Numeradas como RN01…RN18. Manter essa numeração estável: o texto do documento faz referência cruzada a elas.

| # | Regra |
|---|---|
| RN01 | E-mail de conta é único na plataforma. |
| RN02 | Uma conta tem no máximo uma assinatura ativa por vez. |
| RN03 | Nº de perfis da conta não excede o `max_perfis` do plano vigente. |
| RN04 | Perfil pertence a exatamente uma conta, sem transferência. |
| RN05 | Perfil infantil só acessa títulos com classificação ≤ 12 anos. |
| RN06 | Todo título é filme **ou** série — especialização total e exclusiva. |
| RN07 | Temporada só existe vinculada a série; episódio só a temporada. |
| RN08 | Nº da temporada é único na série; nº do episódio é único na temporada. |
| RN09 | Todo título tem ao menos um gênero. |
| RN10 | Gênero pode ter gênero-pai; hierarquia sem ciclos. |
| RN11 | Combinação (título, pessoa, papel) é única. |
| RN12 | Visualização refere-se a um filme **ou** a um episódio, nunca aos dois. |
| RN13 | Tempo assistido não excede a duração do conteúdo. |
| RN14 | Perfil avalia um título no máximo uma vez; nota de 1 a 5. |
| RN15 | Só avalia quem já tem visualização do título. |
| RN16 | Título não se repete na lista do mesmo perfil. |
| RN17 | Exclusão de conta cascateia para perfis e histórico. |
| RN18 | Título retirado do catálogo recebe data de saída; não é apagado. |

RN14 a RN16 dependem das entidades opcionais. Se `avaliacao` e `item_lista` não entrarem no modelo, essas três regras saem do documento — não deixe regra órfã referenciando entidade inexistente.

---

## 6. Justificativas a desenvolver no Modelo Lógico

Estes são os argumentos que sustentam a Parte 2. O texto precisa desenvolvê-los, não apenas listá-los.

**Especialização `titulo` → `filme` / `serie`.** Apresentar as três estratégias (tabela única com discriminador; uma tabela por subtipo sem supertipo; supertipo + subtipos com PK compartilhada) e justificar a escolha da terceira: preserva a natureza total e exclusiva da especialização, evita colunas nulas em massa e mantém consultas sobre "todos os títulos" simples. Custo assumido: JOIN para montar a visão completa.

**`valor_cobrado` em `assinatura`.** Parece redundância em relação a `plano.preco_mensal`, mas é dado histórico — o preço do plano muda, as cobranças passadas precisam permanecer corretas. Explicitar isso, senão a banca lê como violação de normalização.

**Ausência de `total_temporadas` em `serie`.** Atributo derivável por `COUNT` sobre `temporada`; foi deliberadamente omitido. Se o grupo optar por incluí-lo por desempenho, precisa ser declarado como desnormalização consciente e mantido por trigger.

**`participacao` com PK composta `(id_titulo, id_pessoa, papel)`.** Está em 3FN: `personagem` e `ordem_credito` dependem da chave inteira.

**Relacionamento exclusivo em `visualizacao`.** Duas FKs anuláveis mais um `CHECK` garantindo que exatamente uma esteja preenchida. Mencionar a alternativa descartada: criar um supertipo "conteúdo exibível" acima de `filme` e `episodio` — mais elegante conceitualmente, mais pesado para o escopo da disciplina.

**Auto-relacionamentos.** `genero.id_genero_pai` e `titulo.id_titulo_origem` são opcionais (aceitam NULL na raiz) e exigem cuidado contra ciclos.

---

## 7. O que fazer neste repositório

Ordem sugerida de trabalho:

1. Inspecionar a estrutura atual de `.tex` e o preâmbulo antes de escrever qualquer coisa. Descobrir qual classe de documento, quais pacotes já estão carregados e se existe um padrão de numeração de seções.
2. Criar ou preencher as seções correspondentes às três partes.
3. Só então cuidar de figuras, listagens e referências cruzadas.

O que precisa existir no documento final:

- Capa com título, disciplina, professor e os 4 integrantes.
- Introdução curta apresentando a NextMedia.
- Seção de minimundo (base: seção 3 deste briefing, expandida).
- Tabela ou lista de regras de negócio RN01–RN18.
- DER com legenda e referência no texto.
- Seção de modelo lógico com o diagrama e as justificativas da seção 6.
- Seção de modelo físico com trechos comentados do `.sql`.
- Referências bibliográficas (Elmasri & Navathe; Silberschatz, Korth & Sudarshan; Date).

---

## 8. Convenções do documento

- **Idioma:** português, `\usepackage[brazil]{babel}`, codificação UTF-8.
- **Termos técnicos em inglês** (`trigger`, `stored procedure`, `window function`, `constraint`) em itálico na primeira ocorrência.
- **Nomes de tabelas e colunas** em `\texttt{}`.
- **Código SQL:** usar `listings` ou `minted` — verificar qual já está no preâmbulo antes de adicionar outro. Não carregar os dois.
- **Diagramas:** incluir como imagem (`\includegraphics`) exportada do pgAdmin, dentro de ambiente `figure` com `\caption` e `\label`. Não tentar redesenhar o DER em TikZ — consome tempo demais e o professor pediu a ferramenta CASE.
- **Referência a figuras e tabelas** sempre via `\ref`, nunca "a figura abaixo".
- **Tabelas longas** (a de regras de negócio, por exemplo) com `longtable` ou `tabularx` para não estourar a margem.

---

## 9. Pontos ainda em aberto

Decidir com o grupo antes de fechar o documento:

- Entram as entidades opcionais (`avaliacao`, `item_lista`) para chegar a 15? Isso muda a contagem, o DER e a validade das regras RN14–RN16.
- A notação do DER será pé-de-galinha (padrão do ERD Tool do pgAdmin) ou Chen? O professor mostrou pgAdmin em aula, então pé-de-galinha é o caminho de menor atrito.
- O `.sql` entra no documento por completo, em apêndice, ou apenas em trechos ilustrativos?
- Divisão de autoria das seções entre os 4 integrantes.

---

## 10. Como me ajudar melhor

- Se uma informação necessária não estiver neste briefing, **pergunte** em vez de inventar dados sobre o minimundo — números de entidades, regras e nomes já foram acordados pelo grupo.
- Ao propor texto para o documento, escreva em prosa acadêmica corrida, não em tópicos. As listas deste briefing são material bruto, não o formato final.
- Mudanças estruturais no preâmbulo (trocar classe, trocar pacote de código) precisam ser sinalizadas antes de executadas — o repositório é compartilhado entre quatro pessoas.
