-- ============================================================================
-- NextMedia -- plataforma de streaming de video por assinatura
-- Projeto Final de Banco de Dados I -- UNESP/FC Bauru

-- SGBD: PostgreSQL.

-- DROP SCHEMA IF EXISTS nextmedia CASCADE;

CREATE SCHEMA IF NOT EXISTS nextmedia;
SET search_path TO nextmedia;

-- ============================================================================
-- NUCLEO 1 -- ASSINATURA
-- ============================================================================

-- Catalogo de planos comercializados. Nao depende de ninguem, por isso abre
-- o script.
CREATE TABLE plano (
    id_plano          SERIAL,
    nome              VARCHAR(60)    NOT NULL,
    preco_mensal      NUMERIC(10,2)  NOT NULL,
    max_telas         SMALLINT       NOT NULL,
    max_perfis        SMALLINT       NOT NULL,
    qualidade_video   VARCHAR(10)    NOT NULL,

    CONSTRAINT pk_plano            PRIMARY KEY (id_plano),
    CONSTRAINT uq_plano_nome       UNIQUE (nome),
    CONSTRAINT ck_plano_preco      CHECK (preco_mensal >= 0),
    CONSTRAINT ck_plano_telas      CHECK (max_telas BETWEEN 1 AND 8),
    CONSTRAINT ck_plano_perfis     CHECK (max_perfis BETWEEN 1 AND 10),
    CONSTRAINT ck_plano_qualidade  CHECK (qualidade_video IN ('SD', 'HD', '4K'))
);


-- Assinante da plataforma.

CREATE TABLE conta (
    id_conta       SERIAL,
    email          VARCHAR(255) NOT NULL,
    senha_hash     VARCHAR(255) NOT NULL,
    nome_titular   VARCHAR(120) NOT NULL,
    data_cadastro  DATE         NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT pk_conta                 PRIMARY KEY (id_conta),
    CONSTRAINT uq_conta_email           UNIQUE (email),
    CONSTRAINT ck_conta_email           CHECK (POSITION('@' IN email) > 1),
    CONSTRAINT ck_conta_email_minusculo CHECK (email = LOWER(email))
);


-- Vinculo entre conta e plano, com vigencia propria.

CREATE TABLE assinatura (
    id_assinatura  SERIAL,
    id_conta       INTEGER        NOT NULL,
    id_plano       INTEGER        NOT NULL,
    data_inicio    DATE           NOT NULL,
    data_fim       DATE,
    valor_cobrado  NUMERIC(10,2)  NOT NULL,

    CONSTRAINT pk_assinatura         PRIMARY KEY (id_assinatura),
    CONSTRAINT fk_assinatura_conta   FOREIGN KEY (id_conta)
        REFERENCES conta (id_conta) ON DELETE CASCADE,       -- RN17
    CONSTRAINT fk_assinatura_plano   FOREIGN KEY (id_plano)
        REFERENCES plano (id_plano) ON DELETE RESTRICT,
    CONSTRAINT ck_assinatura_valor   CHECK (valor_cobrado >= 0),
    CONSTRAINT ck_assinatura_periodo CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

-- RN02 -- no maximo uma assinatura ativa por conta.
CREATE UNIQUE INDEX uq_assinatura_ativa
    ON assinatura (id_conta)
    WHERE data_fim IS NULL;


-- Subusuario dentro de uma conta.
-- RN04 (perfil nao se transfere) esta garantida pela estrutura: o perfil so
-- existe pendurado numa conta. Impedir o UPDATE de id_conta exigiria gatilho.
CREATE TABLE perfil (
    id_perfil     SERIAL,
    id_conta      INTEGER      NOT NULL,
    nome          VARCHAR(60)  NOT NULL,
    avatar        VARCHAR(255),
    idioma        VARCHAR(10)  NOT NULL DEFAULT 'pt-BR',
    infantil      BOOLEAN      NOT NULL DEFAULT FALSE,
    data_criacao  DATE         NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT pk_perfil       PRIMARY KEY (id_perfil),
    CONSTRAINT fk_perfil_conta FOREIGN KEY (id_conta)
        REFERENCES conta (id_conta) ON DELETE CASCADE,       -- RN17
    CONSTRAINT uq_perfil_nome  UNIQUE (id_conta, nome)
);


-- ============================================================================
-- NUCLEO 2 -- CATALOGO
-- ============================================================================

-- Categoria do catalogo, com hierarquia via auto-relacionamento.
-- id_genero_pai e NULL na raiz da hierarquia.
CREATE TABLE genero (
    id_genero      SERIAL,
    nome           VARCHAR(60)  NOT NULL,
    descricao      VARCHAR(255),
    id_genero_pai  INTEGER,

    CONSTRAINT pk_genero      PRIMARY KEY (id_genero),
    CONSTRAINT uq_genero_nome UNIQUE (nome),
    CONSTRAINT fk_genero_pai  FOREIGN KEY (id_genero_pai)
        REFERENCES genero (id_genero) ON DELETE RESTRICT,
    -- RN10 (parcial): barra o ciclo de tamanho 1, o genero que e pai de si
    -- mesmo. Ciclos maiores (A -> B -> A) precisam de gatilho: um CHECK
    -- enxerga apenas a linha gravada, nunca a arvore inteira.
    CONSTRAINT ck_genero_pai  CHECK (id_genero_pai <> id_genero)
);


-- Unidade do catalogo e supertipo da especializacao.
CREATE TABLE titulo (
    id_titulo                 SERIAL,
    tipo                      CHAR(1)      NOT NULL,
    nome                      VARCHAR(200) NOT NULL,
    ano_lancamento            SMALLINT     NOT NULL,
    sinopse                   TEXT,
    idioma_original           VARCHAR(10)  NOT NULL,
    classificacao_indicativa  SMALLINT     NOT NULL,
    data_entrada              DATE         NOT NULL DEFAULT CURRENT_DATE,
    data_saida                DATE,
    id_titulo_origem          INTEGER,

    CONSTRAINT pk_titulo         PRIMARY KEY (id_titulo),
    -- Redundante em relacao a pk_titulo, mas necessaria: o PostgreSQL
    -- exige uma restricao unica sobre exatamente as colunas que a chave
    -- estrangeira composta dos subtipos referencia.
    CONSTRAINT uq_titulo_tipo    UNIQUE (id_titulo, tipo),
    CONSTRAINT fk_titulo_origem  FOREIGN KEY (id_titulo_origem)
        REFERENCES titulo (id_titulo) ON DELETE RESTRICT,
    CONSTRAINT ck_titulo_tipo    CHECK (tipo IN ('F', 'S')),           -- RN06
    CONSTRAINT ck_titulo_origem  CHECK (id_titulo_origem <> id_titulo),
    CONSTRAINT ck_titulo_ano     CHECK (ano_lancamento BETWEEN 1888 AND 2200),
    CONSTRAINT ck_titulo_class   CHECK (classificacao_indicativa IN (0, 10, 12, 14, 16, 18)),
    CONSTRAINT ck_titulo_saida   CHECK (data_saida IS NULL OR data_saida >= data_entrada)
);


-- RN06 -- subtipo: titulo que se assiste de uma vez.
-- A chave primaria e, ao mesmo tempo, chave estrangeira para o supertipo.
CREATE TABLE filme (
    id_filme     INTEGER  NOT NULL,
    tipo         CHAR(1)  NOT NULL DEFAULT 'F',
    duracao_min  SMALLINT NOT NULL,

    CONSTRAINT pk_filme         PRIMARY KEY (id_filme),
    CONSTRAINT ck_filme_tipo    CHECK (tipo = 'F'),
    CONSTRAINT fk_filme_titulo  FOREIGN KEY (id_filme, tipo)
        REFERENCES titulo (id_titulo, tipo) ON DELETE CASCADE,
    CONSTRAINT ck_filme_duracao CHECK (duracao_min > 0)
);


-- RN06 -- subtipo: titulo que se desdobra em temporadas.
CREATE TABLE serie (
    id_serie          INTEGER  NOT NULL,
    tipo              CHAR(1)  NOT NULL DEFAULT 'S',
    ano_encerramento  SMALLINT,
    em_producao       BOOLEAN  NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_serie        PRIMARY KEY (id_serie),
    CONSTRAINT ck_serie_tipo   CHECK (tipo = 'S'),
    CONSTRAINT fk_serie_titulo FOREIGN KEY (id_serie, tipo)
        REFERENCES titulo (id_titulo, tipo) ON DELETE CASCADE,
    -- Serie com ano de encerramento nao pode continuar em producao.
    CONSTRAINT ck_serie_fim    CHECK (ano_encerramento IS NULL OR NOT em_producao)
);


-- Entidade fraca: depende de uma serie para existir.
CREATE TABLE temporada (
    id_serie        INTEGER   NOT NULL,
    num_temporada   SMALLINT  NOT NULL,
    ano_lancamento  SMALLINT,
    subtitulo       VARCHAR(120),

    CONSTRAINT pk_temporada       PRIMARY KEY (id_serie, num_temporada),
    CONSTRAINT fk_temporada_serie FOREIGN KEY (id_serie)
        REFERENCES serie (id_serie) ON DELETE CASCADE,
    CONSTRAINT ck_temporada_num   CHECK (num_temporada > 0),
    CONSTRAINT ck_temporada_ano   CHECK (ano_lancamento IS NULL
                                         OR ano_lancamento BETWEEN 1888 AND 2200)
);


-- Entidade fraca de segundo nivel: depende da temporada, que depende da serie.
CREATE TABLE episodio (
    id_serie       INTEGER      NOT NULL,
    num_temporada  SMALLINT     NOT NULL,
    num_episodio   SMALLINT     NOT NULL,
    nome           VARCHAR(200) NOT NULL,
    data_estreia   DATE,
    sinopse        TEXT,
    duracao_min    SMALLINT     NOT NULL,

    CONSTRAINT pk_episodio           PRIMARY KEY (id_serie, num_temporada, num_episodio),
    CONSTRAINT fk_episodio_temporada FOREIGN KEY (id_serie, num_temporada)
        REFERENCES temporada (id_serie, num_temporada) ON DELETE CASCADE,
    CONSTRAINT ck_episodio_num       CHECK (num_episodio > 0),        -- RN08
    CONSTRAINT ck_episodio_duracao   CHECK (duracao_min > 0)
);


-- Relacionamento N:N sem atributos proprios entre titulo e genero.
CREATE TABLE titulo_genero (
    id_titulo  INTEGER NOT NULL,
    id_genero  INTEGER NOT NULL,

    CONSTRAINT pk_titulo_genero        PRIMARY KEY (id_titulo, id_genero),
    CONSTRAINT fk_titulo_genero_titulo FOREIGN KEY (id_titulo)
        REFERENCES titulo (id_titulo) ON DELETE CASCADE,
    CONSTRAINT fk_titulo_genero_genero FOREIGN KEY (id_genero)
        REFERENCES genero (id_genero) ON DELETE CASCADE
);


-- ============================================================================
-- NUCLEO 3 -- PESSOAS
-- ============================================================================

-- Elenco e equipe tecnica, registrados uma unica vez.
CREATE TABLE pessoa (
    id_pessoa        SERIAL,
    nome             VARCHAR(120) NOT NULL,
    data_nascimento  DATE,
    nacionalidade    VARCHAR(60),

    CONSTRAINT pk_pessoa PRIMARY KEY (id_pessoa)
);


-- Relacionamento N:N COM atributos proprios entre titulo e pessoa.

-- Cascateia dos dois lados: uma participacao nao significa nada sem o titulo
-- nem sem a pessoa. Nao e aqui que a RN18 se defende -- proteger o catalogo
-- do DELETE e trabalho do gatilho, nao de uma chave estrangeira.
CREATE TABLE participacao (
    id_titulo      INTEGER     NOT NULL,
    id_pessoa      INTEGER     NOT NULL,
    papel          VARCHAR(30) NOT NULL,
    personagem     VARCHAR(120),
    ordem_credito  SMALLINT,

    CONSTRAINT pk_participacao        PRIMARY KEY (id_titulo, id_pessoa, papel),
    CONSTRAINT fk_participacao_titulo FOREIGN KEY (id_titulo)
        REFERENCES titulo (id_titulo) ON DELETE CASCADE,
    CONSTRAINT fk_participacao_pessoa FOREIGN KEY (id_pessoa)
        REFERENCES pessoa (id_pessoa) ON DELETE CASCADE,
    CONSTRAINT ck_participacao_papel  CHECK (papel IN ('ator', 'diretor', 'roteirista')),
    CONSTRAINT ck_participacao_ordem  CHECK (ordem_credito IS NULL OR ordem_credito > 0),
    -- So quem atua interpreta personagem.
    CONSTRAINT ck_participacao_personagem CHECK (papel = 'ator' OR personagem IS NULL)
);


-- ============================================================================
-- NUCLEO 4 -- CONSUMO
-- ============================================================================

CREATE TABLE visualizacao (
    id_visualizacao      SERIAL,
    id_perfil            INTEGER    NOT NULL,
    id_filme             INTEGER,
    id_serie             INTEGER,
    num_temporada        SMALLINT,
    num_episodio         SMALLINT,
    data_hora            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tempo_assistido_seg  INTEGER    NOT NULL,
    dispositivo          VARCHAR(40),
    concluiu             BOOLEAN    NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_visualizacao          PRIMARY KEY (id_visualizacao),
    CONSTRAINT fk_visualizacao_perfil   FOREIGN KEY (id_perfil)
        REFERENCES perfil (id_perfil) ON DELETE CASCADE,     -- RN17
    CONSTRAINT fk_visualizacao_filme    FOREIGN KEY (id_filme)
        REFERENCES filme (id_filme) ON DELETE RESTRICT,      -- RN18
    CONSTRAINT fk_visualizacao_episodio FOREIGN KEY (id_serie, num_temporada, num_episodio)
        REFERENCES episodio (id_serie, num_temporada, num_episodio)
        ON DELETE RESTRICT,                                            -- RN18
    CONSTRAINT ck_visualizacao_tempo    CHECK (tempo_assistido_seg >= 0),
    CONSTRAINT ck_visualizacao_dispositivo CHECK (dispositivo IS NULL
        OR dispositivo IN ('tv', 'celular', 'tablet', 'computador', 'console')),
    
    CONSTRAINT ck_visualizacao_exclusivo CHECK (
        (id_filme IS NOT NULL
         AND id_serie IS NULL AND num_temporada IS NULL AND num_episodio IS NULL)
        OR
        (id_filme IS NULL
         AND id_serie IS NOT NULL AND num_temporada IS NOT NULL AND num_episodio IS NOT NULL)
    )
);


-- ============================================================================
-- REGRAS QUE ESTE DDL NAO GARANTE
-- ============================================================================
-- As regras abaixo dependem de informacao que nao esta na linha gravada. Um
-- CHECK enxerga apenas a propria linha, e uma chave estrangeira apenas a
-- existencia da linha referenciada; nenhum dos dois alcanca outra tabela ou
-- uma arvore. Todas entram na proxima parte do script, como gatilhos.
--
--   RN03  Numero de perfis da conta nao excede o max_perfis do plano vigente.
--         O limite esta a duas tabelas de distancia: perfil -> conta ->
--         assinatura ativa -> plano.
--
--   RN06  A especializacao e TOTAL: todo titulo precisa estar em filme ou em
--         serie. A exclusividade ja esta resolvida acima, pela chave
--         estrangeira composta. A totalidade nao: no instante em que a linha
--         de titulo e inserida, a linha do subtipo ainda nao existe, o que
--         exige verificacao adiada ou gatilho.
--
--   RN09  Todo titulo tem ao menos um genero. Sao dois caminhos a cobrir. Na
--         insercao, o mesmo problema da RN06: o vinculo em titulo_genero so
--         pode ser criado depois do titulo. Na remocao, apagar um genero
--         cascateia para titulo_genero e pode tirar do titulo o ultimo que
--         ele tinha.
--
--   RN10  Hierarquia de genero sem ciclos. O ck_genero_pai acima barra apenas
--         o ciclo de tamanho 1; detectar A -> B -> A exige percorrer a arvore
--         com WITH RECURSIVE.
--
--   RN13  Tempo assistido nao excede a duracao do conteudo. Parece verificacao
--         local, mas duracao_min mora em filme ou em episodio, e um CHECK nao
--         enxerga outra tabela.
--
--   RN18  Titulo nao e removido fisicamente, so recebe data_saida. Nenhuma
--         chave estrangeira impede o DELETE: as referencias vindas de
--         participacao, titulo_genero e dos subtipos cascateiam, por decisao
--         de projeto (ver ACOES DE PROPAGACAO no cabecalho). So o RESTRICT de
--         visualizacao barra, e apenas para conteudo ja assistido. A regra e
--         responsabilidade de um gatilho BEFORE DELETE em titulo, e sem ele
--         um DELETE leva o titulo, o elenco e os generos de uma vez.
--
--   RN05  Perfil infantil so acessa titulos de classificacao ate 12 anos. E de
--         outra natureza: diz respeito ao que um perfil pode VER, nao ao que
--         pode existir no banco. Cabe a camada de aplicacao ou a uma visao.
--
-- Fora da numeracao, um caso que o minimundo cita e nenhuma RN enuncia:
--
--   Ciclo em titulo.id_titulo_origem. O ck_titulo_origem barra o titulo que se
--   origina de si mesmo, mas A -> B -> A passa. E o mesmo problema da RN10, na
--   outra hierarquia, e tem a mesma solucao.
-- ============================================================================


-- ============================================================================
-- GATILHOS
-- ============================================================================
-- Os gatilhos DEFERRABLE INITIALLY DEFERRED so rodam no COMMIT. Como o
-- pgAdmin usa autocommit, cada INSERT vira uma transacao sozinha e o
-- adiamento nao ajuda: a carga precisa agrupar os inserts relacionados entre
-- BEGIN e COMMIT explicitos.


-- RN03 -- numero de perfis nao excede o max_perfis do plano vigente.
CREATE FUNCTION fn_perfil_limite() RETURNS TRIGGER AS $$
DECLARE
    limite INTEGER;
    atuais INTEGER;
BEGIN
    SELECT p.max_perfis INTO limite
      FROM assinatura a
      JOIN plano p ON p.id_plano = a.id_plano
     WHERE a.id_conta = NEW.id_conta
       AND a.data_fim IS NULL;

    IF limite IS NULL THEN
        RAISE EXCEPTION 'RN03: conta % nao tem assinatura ativa', NEW.id_conta;
    END IF;

    SELECT COUNT(*) INTO atuais FROM perfil WHERE id_conta = NEW.id_conta;

    IF atuais >= limite THEN
        RAISE EXCEPTION 'RN03: conta % ja tem % perfis, o plano permite %',
                        NEW.id_conta, atuais, limite;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_perfil_limite
    BEFORE INSERT ON perfil
    FOR EACH ROW EXECUTE FUNCTION fn_perfil_limite();


-- RN06 -- a especializacao e total: todo titulo esta em filme ou em serie.
-- Adiado porque a linha do subtipo so pode existir depois da linha do titulo.
CREATE FUNCTION fn_titulo_total() RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM filme WHERE id_filme = NEW.id_titulo)
       AND NOT EXISTS (SELECT 1 FROM serie WHERE id_serie = NEW.id_titulo) THEN
        RAISE EXCEPTION 'RN06: titulo % nao foi gravado como filme nem como serie',
                        NEW.id_titulo;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tg_titulo_total
    AFTER INSERT ON titulo
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_titulo_total();


-- RN09 -- todo titulo tem ao menos um genero.
-- Dois caminhos, mesma verificacao: a insercao do titulo e a remocao de um
-- vinculo. O primeiro IF cobre o titulo que foi apagado e levou os vinculos
-- por CASCADE, caso em que nao ha nada a exigir.
CREATE FUNCTION fn_titulo_genero_minimo() RETURNS TRIGGER AS $$
DECLARE
    alvo INTEGER;
BEGIN
    -- NEW nao existe em gatilho de DELETE, por isso o desvio por TG_OP.
    IF TG_OP = 'DELETE' THEN
        alvo := OLD.id_titulo;
    ELSE
        alvo := NEW.id_titulo;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM titulo WHERE id_titulo = alvo) THEN
        RETURN NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM titulo_genero WHERE id_titulo = alvo) THEN
        RAISE EXCEPTION 'RN09: titulo % ficou sem genero', alvo;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER tg_titulo_genero_insercao
    AFTER INSERT ON titulo
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_titulo_genero_minimo();

CREATE CONSTRAINT TRIGGER tg_titulo_genero_remocao
    AFTER DELETE ON titulo_genero
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_titulo_genero_minimo();


-- RN10 -- a hierarquia de genero nao admite ciclos.
-- O ck_genero_pai da tabela ja barra o ciclo de tamanho 1. Aqui a consulta
-- recursiva sobe a cadeia de pais a partir do pai proposto; se reencontrar o
-- proprio genero, fecharia um ciclo.
CREATE FUNCTION fn_genero_sem_ciclo() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_genero_pai IS NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        WITH RECURSIVE ancestral(id) AS (
            SELECT NEW.id_genero_pai
            UNION ALL
            SELECT g.id_genero_pai
              FROM genero g
              JOIN ancestral a ON g.id_genero = a.id
             WHERE g.id_genero_pai IS NOT NULL
        )
        SELECT 1 FROM ancestral WHERE id = NEW.id_genero
    ) THEN
        RAISE EXCEPTION 'RN10: o genero % fecharia um ciclo na hierarquia',
                        NEW.id_genero;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_genero_sem_ciclo
    BEFORE INSERT OR UPDATE ON genero
    FOR EACH ROW EXECUTE FUNCTION fn_genero_sem_ciclo();


-- Mesma verificacao na outra hierarquia, a das franquias. Nenhuma RN enuncia
-- este caso, mas o minimundo pede o mesmo cuidado.
CREATE FUNCTION fn_titulo_sem_ciclo() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_titulo_origem IS NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        WITH RECURSIVE origem(id) AS (
            SELECT NEW.id_titulo_origem
            UNION ALL
            SELECT t.id_titulo_origem
              FROM titulo t
              JOIN origem o ON t.id_titulo = o.id
             WHERE t.id_titulo_origem IS NOT NULL
        )
        SELECT 1 FROM origem WHERE id = NEW.id_titulo
    ) THEN
        RAISE EXCEPTION 'titulo %: a cadeia de origem fecharia um ciclo',
                        NEW.id_titulo;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_titulo_sem_ciclo
    BEFORE INSERT OR UPDATE ON titulo
    FOR EACH ROW EXECUTE FUNCTION fn_titulo_sem_ciclo();


-- RN13 -- o tempo assistido nao excede a duracao do conteudo.
-- A duracao mora em filme ou em episodio, conforme o lado preenchido, e por
-- isso um CHECK de linha nao alcanca. duracao_min esta em minutos.
CREATE FUNCTION fn_visualizacao_duracao() RETURNS TRIGGER AS $$
DECLARE
    duracao SMALLINT;
BEGIN
    IF NEW.id_filme IS NOT NULL THEN
        SELECT duracao_min INTO duracao
          FROM filme WHERE id_filme = NEW.id_filme;
    ELSE
        SELECT duracao_min INTO duracao
          FROM episodio
         WHERE id_serie      = NEW.id_serie
           AND num_temporada = NEW.num_temporada
           AND num_episodio  = NEW.num_episodio;
    END IF;

    IF NEW.tempo_assistido_seg > duracao * 60 THEN
        RAISE EXCEPTION 'RN13: % s assistidos excedem os % min do conteudo',
                        NEW.tempo_assistido_seg, duracao;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_visualizacao_duracao
    BEFORE INSERT OR UPDATE ON visualizacao
    FOR EACH ROW EXECUTE FUNCTION fn_visualizacao_duracao();


-- RN18 -- titulo nao e removido, so recebe data_saida.
-- Com os CASCADE do catalogo, este gatilho e a unica barreira: sem ele um
-- DELETE leva o titulo, o elenco e os generos de uma vez.
CREATE FUNCTION fn_titulo_sem_delete() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'RN18: titulo % nao e removido; preencha data_saida',
                    OLD.id_titulo;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_titulo_sem_delete
    BEFORE DELETE ON titulo
    FOR EACH ROW EXECUTE FUNCTION fn_titulo_sem_delete();
