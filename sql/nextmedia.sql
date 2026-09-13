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


-- ============================================================================
-- CARGA DE DADOS DE EXEMPLO
-- ============================================================================
-- Base ilustrativa. Titulos, episodios e nomes de elenco sao reais; contas,
-- perfis e visualizacoes sao ficticios.

-- As series entram como recorte, nao completas: Dark com as tres temporadas,
-- as outras tres so com a primeira. Carregar Breaking Bad, Better Call Saul e
-- Sopranos por inteiro daria 211 episodios, fora da escala deste exemplo.

BEGIN;

-- ---------------------------------------------------------------- planos ---
INSERT INTO plano (id_plano, nome, preco_mensal, max_telas, max_perfis, qualidade_video) VALUES
    (1, 'Basico',        19.90, 1, 2, 'SD'),
    (2, 'Intermediario', 39.90, 2, 4, 'HD'),
    (3, 'Premium',       59.90, 4, 6, '4K');
SELECT setval('plano_id_plano_seq', (SELECT MAX(id_plano) FROM plano));

-- ---------------------------------------------------------------- contas ---
-- O e-mail vai em minusculas: ck_conta_email_minusculo recusa qualquer outra
-- forma, e a unicidade da RN01 so funciona sobre texto normalizado.
INSERT INTO conta (id_conta, email, senha_hash, nome_titular, data_cadastro) VALUES
    (1, 'americo@exemplo.com',    'hash-exemplo-01', 'Americo',    '2026-01-10'),
    (2, 'andrea@exemplo.com',     'hash-exemplo-02', 'Andrea',     '2025-08-03'),
    (3, 'clayton@exemplo.com',    'hash-exemplo-03', 'Clayton',    '2025-02-01'),
    (4, 'thiago@exemplo.com',     'hash-exemplo-04', 'Thiago',     '2026-03-15'),
    (5, 'diretoria@exemplo.com',  'hash-exemplo-05', 'Diretoria',  '2024-09-01'),
    (6, 'segundoano@exemplo.com', 'hash-exemplo-06', 'Segundo Ano','2026-02-20');
SELECT setval('conta_id_conta_seq', (SELECT MAX(id_conta) FROM conta));

-- ----------------------------------------------------------- assinaturas ---
-- Clayton e a diretoria trocaram de plano: a assinatura anterior foi
-- encerrada e uma nova aberta. O valor_cobrado das encerradas e 17.90, o
-- preco que o Basico tinha na epoca, e nao os 19.90 de hoje. E esse
-- descasamento que justifica a coluna existir.
--
-- O uq_assinatura_ativa garante que nenhuma conta tenha duas com data_fim
-- nula ao mesmo tempo (RN02).
INSERT INTO assinatura (id_assinatura, id_conta, id_plano, data_inicio, data_fim, valor_cobrado) VALUES
    (1, 1, 2, '2026-01-10', NULL,         39.90),
    (2, 2, 1, '2025-08-03', NULL,         19.90),
    (3, 3, 1, '2025-02-01', '2025-11-30', 17.90),
    (4, 3, 3, '2025-12-01', NULL,         59.90),
    (5, 4, 1, '2026-03-15', NULL,         19.90),
    (6, 5, 1, '2024-09-01', '2025-06-30', 17.90),
    (7, 5, 2, '2025-07-01', NULL,         39.90),
    (8, 6, 1, '2026-02-20', NULL,         19.90);
SELECT setval('assinatura_id_assinatura_seq', (SELECT MAX(id_assinatura) FROM assinatura));

-- ---------------------------------------------------------------- perfis ---
-- Andrea, a diretoria e o segundo ano estao no limite de perfis do plano
-- vigente: um perfil a mais em qualquer uma delas e recusado pela RN03.
INSERT INTO perfil (id_perfil, id_conta, nome, idioma, infantil) VALUES
    ( 1, 1, 'fisica1',      'pt-BR', FALSE),
    ( 2, 1, 'fisica2',      'pt-BR', FALSE),
    ( 3, 1, 'fisica3',      'pt-BR', FALSE),
    ( 4, 2, 'alg1',         'pt-BR', FALSE),
    ( 5, 2, 'alg2',         'pt-BR', FALSE),
    ( 6, 3, 'circuitos',    'pt-BR', FALSE),
    ( 7, 3, 'BDI',          'pt-BR', FALSE),
    ( 8, 3, 'CienciaDados', 'en-US', FALSE),
    ( 9, 4, 'redes',        'pt-BR', FALSE),
    (10, 5, 'Toreto',       'pt-BR', FALSE),
    (11, 5, 'Igao',         'pt-BR', FALSE),
    (12, 5, 'Tapa',         'pt-BR', TRUE),
    (13, 5, 'Gatti',        'pt-BR', FALSE),
    (14, 6, 'Adao',         'pt-BR', FALSE),
    (15, 6, 'Rossi',        'pt-BR', FALSE);
SELECT setval('perfil_id_perfil_seq', (SELECT MAX(id_perfil) FROM perfil));

-- --------------------------------------------------------------- generos ---
-- Hierarquia de tres niveis: Drama contem Crime, que contem Policial. E o que
-- da o que percorrer a consulta recursiva.
INSERT INTO genero (id_genero, nome, descricao, id_genero_pai) VALUES
    ( 1, 'Drama',             'Conflito humano em primeiro plano',  NULL),
    ( 2, 'Comedia',           'Narrativa comica',                   NULL),
    ( 3, 'Acao',              'Enredo movido por confronto fisico', NULL),
    ( 4, 'Animacao',          'Obra animada',                       NULL),
    ( 5, 'Crime',             'Mundo do crime e suas consequencias',   1),
    ( 6, 'Policial',          'Investigacao e aplicacao da lei',       5),
    ( 7, 'Suspense',          'Tensao e revelacao gradual',            1),
    ( 8, 'Ficcao cientifica', 'Especulacao a partir da ciencia',       1),
    ( 9, 'Guerra',            'Conflito armado e seus efeitos',        1),
    (10, 'Faroeste',          'Oeste americano',                       3),
    (11, 'Aventura',          'Jornada e descoberta',                  3),
    (12, 'Comedia romantica', 'Encontro amoroso em chave comica',      2);
SELECT setval('genero_id_genero_seq', (SELECT MAX(id_genero) FROM genero));

-- --------------------------------------------------------------- titulos ---
-- Onze filmes e quatro series. id_titulo_origem liga duas cadeias: a
-- trilogia do Poderoso Chefao e Better Call Saul, que e prequela de
-- Breaking Bad.
--
-- Apocalypse Now tem data_saida preenchida: saiu do catalogo e permaneceu no
-- banco, como a RN18 exige, para que as visualizacoes antigas continuem
-- fazendo sentido.
INSERT INTO titulo (id_titulo, tipo, nome, ano_lancamento, idioma_original,
                    classificacao_indicativa, data_entrada, data_saida,
                    id_titulo_origem, sinopse) VALUES
    ( 1, 'F', 'Pulp Fiction',                    1994, 'en-US', 18, '2024-01-15', NULL,         NULL, 'Historias cruzadas no submundo de Los Angeles.'),
    ( 2, 'F', 'Django Unchained',                2012, 'en-US', 18, '2024-01-15', NULL,         NULL, 'Um escravo liberto caca criminosos no sul escravagista.'),
    ( 3, 'F', 'Apocalypse Now',                  1979, 'en-US', 16, '2024-01-15', '2026-06-30', NULL, 'Uma missao rio acima na Guerra do Vietna.'),
    ( 4, 'F', 'The Godfather',                   1972, 'en-US', 16, '2024-02-01', NULL,         NULL, 'A sucessao no comando de uma familia mafiosa.'),
    ( 5, 'F', 'The Godfather Part II',           1974, 'en-US', 16, '2024-02-01', NULL,            4, 'A ascensao do jovem Vito e a consolidacao de Michael.'),
    ( 6, 'F', 'The Godfather Part III',          1990, 'en-US', 16, '2024-02-01', NULL,            5, 'Michael tenta legitimar os negocios da familia.'),
    ( 7, 'F', 'Monty Python and the Holy Grail', 1975, 'en-US', 12, '2024-03-10', NULL,         NULL, 'A busca pelo Santo Graal, em chave absurda.'),
    ( 8, 'F', 'Ratatouille',                     2007, 'en-US',  0, '2024-03-10', NULL,         NULL, 'Um rato com talento para a cozinha em Paris.'),
    ( 9, 'F', 'Cars',                            2006, 'en-US',  0, '2024-03-10', NULL,         NULL, 'Um carro de corrida preso numa cidade esquecida.'),
    (10, 'F', 'Cidade de Deus',                  2002, 'pt-BR', 18, '2024-05-20', NULL,         NULL, 'Duas trajetorias opostas numa favela carioca.'),
    (11, 'F', 'O Agente Secreto',                2025, 'pt-BR', 16, '2026-02-01', NULL,         NULL, 'Um homem tenta recomecar no Recife de 1977.'),
    (12, 'S', 'The Sopranos',                    1999, 'en-US', 18, '2024-02-01', NULL,         NULL, 'Um chefe mafioso em terapia.'),
    (13, 'S', 'Breaking Bad',                    2008, 'en-US', 16, '2024-02-01', NULL,         NULL, 'Um professor de quimica entra no trafico.'),
    (14, 'S', 'Better Call Saul',                2015, 'en-US', 16, '2024-04-05', NULL,           13, 'Como Jimmy McGill virou Saul Goodman.'),
    (15, 'S', 'Dark',                            2017, 'de-DE', 16, '2024-04-05', NULL,         NULL, 'Quatro familias e um desaparecimento numa cidade alema.');
SELECT setval('titulo_id_titulo_seq', (SELECT MAX(id_titulo) FROM titulo));

-- ---------------------------------------------------- subtipos de titulo ---
-- A coluna tipo nao aparece aqui: o DEFAULT ja a preenche com o valor que o
-- CHECK de cada subtipo exige.
INSERT INTO filme (id_filme, duracao_min) VALUES
    (1, 154), (2, 165), (3, 147), (4, 175), (5, 202), (6, 162),
    (7, 91), (8, 111), (9, 117), (10, 130), (11, 160);

INSERT INTO serie (id_serie, ano_encerramento, em_producao) VALUES
    (12, 2007, FALSE),
    (13, 2013, FALSE),
    (14, 2022, FALSE),
    (15, 2020, FALSE);

-- ----------------------------------------------------- titulos e generos ---
-- Todo titulo recebe ao menos um genero, como a RN09 exige. A verificacao e
-- adiada para o COMMIT, e nao para cada INSERT.
INSERT INTO titulo_genero (id_titulo, id_genero) VALUES
    ( 1, 1), ( 1, 5),
    ( 2, 3), ( 2, 10), ( 2, 1),
    ( 3, 1), ( 3, 9),
    ( 4, 1), ( 4, 5),
    ( 5, 1), ( 5, 5),
    ( 6, 1), ( 6, 5),
    ( 7, 2), ( 7, 11),
    ( 8, 4), ( 8, 2),
    ( 9, 4), ( 9, 11),
    (10, 1), (10, 5),
    (11, 1), (11, 7),
    (12, 1), (12, 5),
    (13, 1), (13, 5), (13, 7),
    (14, 1), (14, 6),
    (15, 1), (15, 8), (15, 7);

-- ------------------------------------------------ temporadas e episodios ---
INSERT INTO temporada (id_serie, num_temporada, ano_lancamento, subtitulo) VALUES
    (12, 1, 1999, NULL),
    (13, 1, 2008, NULL),
    (14, 1, 2015, NULL),
    (15, 1, 2017, NULL),
    (15, 2, 2019, NULL),
    (15, 3, 2020, NULL);

-- The Sopranos, primeira temporada.
INSERT INTO episodio (id_serie, num_temporada, num_episodio, nome, duracao_min) VALUES
    (12, 1,  1, 'The Sopranos',                        60),
    (12, 1,  2, '46 Long',                             55),
    (12, 1,  3, 'Denial, Anger, Acceptance',           53),
    (12, 1,  4, 'Meadowlands',                         55),
    (12, 1,  5, 'College',                             57),
    (12, 1,  6, 'Pax Soprana',                         54),
    (12, 1,  7, 'Down Neck',                           52),
    (12, 1,  8, 'The Legend of Tennessee Moltisanti',  53),
    (12, 1,  9, 'Boca',                                55),
    (12, 1, 10, 'A Hit Is a Hit',                      54),
    (12, 1, 11, 'Nobody Knows Anything',               52),
    (12, 1, 12, 'Isabella',                            52),
    (12, 1, 13, 'I Dream of Jeannie Cusamano',         58);

-- Breaking Bad, primeira temporada.
INSERT INTO episodio (id_serie, num_temporada, num_episodio, nome, duracao_min) VALUES
    (13, 1, 1, 'Pilot',                            58),
    (13, 1, 2, 'Cat''s in the Bag...',             48),
    (13, 1, 3, '...And the Bag''s in the River',   48),
    (13, 1, 4, 'Cancer Man',                       48),
    (13, 1, 5, 'Gray Matter',                      48),
    (13, 1, 6, 'Crazy Handful of Nothin''',        47),
    (13, 1, 7, 'A No-Rough-Stuff-Type Deal',       48);

-- Better Call Saul, primeira temporada.
INSERT INTO episodio (id_serie, num_temporada, num_episodio, nome, duracao_min) VALUES
    (14, 1,  1, 'Uno',                  53),
    (14, 1,  2, 'Mijo',                 47),
    (14, 1,  3, 'Nacho',                47),
    (14, 1,  4, 'Hero',                 47),
    (14, 1,  5, 'Alpine Shepherd Boy',  46),
    (14, 1,  6, 'Five-O',               46),
    (14, 1,  7, 'Bingo',                47),
    (14, 1,  8, 'RICO',                 47),
    (14, 1,  9, 'Pimento',              48),
    (14, 1, 10, 'Marco',                46);

-- Dark, tres temporadas.
INSERT INTO episodio (id_serie, num_temporada, num_episodio, nome, duracao_min) VALUES
    (15, 1, 1, 'Secrets',                          51),
    (15, 1, 2, 'Lies',                             45),
    (15, 1, 3, 'Past and Present',                 51),
    (15, 1, 4, 'Double Lives',                     46),
    (15, 1, 5, 'Truths',                           50),
    (15, 1, 6, 'Sic Mundus Creatus Est',           55),
    (15, 1, 7, 'Crossroads',                       52),
    (15, 1, 8, 'As You Sow, so Shall You Reap',    56),
    (15, 2, 1, 'Beginnings and Endings',           58),
    (15, 2, 2, 'Dark Matter',                      52),
    (15, 2, 3, 'Ghosts',                           50),
    (15, 2, 4, 'The Travelers',                    54),
    (15, 2, 5, 'Lost and Found',                   50),
    (15, 2, 6, 'An Endless Cycle',                 50),
    (15, 2, 7, 'The White Devil',                  49),
    (15, 2, 8, 'Endings and Beginnings',           58),
    (15, 3, 1, 'Deja-vu',                          56),
    (15, 3, 2, 'The Survivors',                    54),
    (15, 3, 3, 'Adam and Eva',                     56),
    (15, 3, 4, 'The Origin',                       52),
    (15, 3, 5, 'Life and Death',                   54),
    (15, 3, 6, 'Light and Shadow',                 58),
    (15, 3, 7, 'Between the Time',                 60),
    (15, 3, 8, 'The Paradise',                     64);

-- --------------------------------------------------------------- pessoas ---
INSERT INTO pessoa (id_pessoa, nome, nacionalidade) VALUES
    ( 1, 'Quentin Tarantino',        'Estados Unidos'),
    ( 2, 'John Travolta',            'Estados Unidos'),
    ( 3, 'Samuel L. Jackson',        'Estados Unidos'),
    ( 4, 'Uma Thurman',              'Estados Unidos'),
    ( 5, 'Jamie Foxx',               'Estados Unidos'),
    ( 6, 'Christoph Waltz',          'Austria'),
    ( 7, 'Francis Ford Coppola',     'Estados Unidos'),
    ( 8, 'Marlon Brando',            'Estados Unidos'),
    ( 9, 'Al Pacino',                'Estados Unidos'),
    (10, 'Robert De Niro',           'Estados Unidos'),
    (11, 'Martin Sheen',             'Estados Unidos'),
    (12, 'Brad Bird',                'Estados Unidos'),
    (13, 'John Lasseter',            'Estados Unidos'),
    (14, 'Fernando Meirelles',       'Brasil'),
    (15, 'Katia Lund',               'Brasil'),
    (16, 'Alexandre Rodrigues',      'Brasil'),
    (17, 'Leandro Firmino',          'Brasil'),
    (18, 'Kleber Mendonca Filho',    'Brasil'),
    (19, 'Wagner Moura',             'Brasil'),
    (20, 'James Gandolfini',         'Estados Unidos'),
    (21, 'Bryan Cranston',           'Estados Unidos'),
    (22, 'Aaron Paul',               'Estados Unidos'),
    (23, 'Vince Gilligan',           'Estados Unidos'),
    (24, 'Bob Odenkirk',             'Estados Unidos'),
    (25, 'Baran bo Odar',            'Alemanha'),
    (26, 'Terry Gilliam',            'Estados Unidos'),
    (27, 'Terry Jones',              'Reino Unido'),
    (28, 'Graham Chapman',           'Reino Unido'),
    (29, 'John Cleese',              'Reino Unido'),
    (30, 'Eric Idle',                'Reino Unido'),
    (31, 'Michael Palin',            'Reino Unido'),
    (32, 'David Chase',              'Estados Unidos'),
    (33, 'Edie Falco',               'Estados Unidos'),
    (34, 'Michael Imperioli',        'Estados Unidos'),
    (35, 'Anna Gunn',                'Estados Unidos'),
    (36, 'Peter Gould',              'Estados Unidos'),
    (37, 'Rhea Seehorn',             'Estados Unidos'),
    (38, 'Jantje Friese',            'Alemanha'),
    (39, 'Louis Hofmann',            'Alemanha');
SELECT setval('pessoa_id_pessoa_seq', (SELECT MAX(id_pessoa) FROM pessoa));


-- personagem so vai preenchido para quem atua: ck_participacao_personagem
-- recusa diretor ou roteirista com personagem.
INSERT INTO participacao (id_titulo, id_pessoa, papel, personagem, ordem_credito) VALUES
    ( 1,  1, 'diretor',    NULL,              1),
    ( 1,  1, 'roteirista', NULL,              1),
    ( 1,  1, 'ator',       'Jimmie',          8),
    ( 1,  2, 'ator',       'Vincent Vega',    1),
    ( 1,  3, 'ator',       'Jules Winnfield', 2),
    ( 1,  4, 'ator',       'Mia Wallace',     3),
    ( 2,  1, 'diretor',    NULL,              1),
    ( 2,  1, 'roteirista', NULL,              1),
    ( 2,  5, 'ator',       'Django',          1),
    ( 2,  6, 'ator',       'Dr. King Schultz',2),
    ( 3,  7, 'diretor',    NULL,              1),
    ( 3, 11, 'ator',       'Willard',         1),
    ( 3,  8, 'ator',       'Kurtz',           2),
    ( 4,  7, 'diretor',    NULL,              1),
    ( 4,  8, 'ator',       'Vito Corleone',   1),
    ( 4,  9, 'ator',       'Michael Corleone',2),
    ( 5,  7, 'diretor',    NULL,              1),
    ( 5,  9, 'ator',       'Michael Corleone',1),
    ( 5, 10, 'ator',       'Vito Corleone',   2),
    ( 6,  7, 'diretor',    NULL,              1),
    ( 6,  9, 'ator',       'Michael Corleone',1),
    ( 8, 12, 'diretor',    NULL,              1),
    ( 8, 12, 'roteirista', NULL,              1),
    ( 9, 13, 'diretor',    NULL,              1),
    (10, 14, 'diretor',    NULL,              1),
    (10, 15, 'diretor',    NULL,              2),
    (10, 16, 'ator',       'Buscape',         1),
    (10, 17, 'ator',       'Ze Pequeno',      2),
    (11, 18, 'diretor',    NULL,              1),
    (11, 18, 'roteirista', NULL,              1),
    (11, 19, 'ator',       'Marcelo',         1),
    (12, 20, 'ator',       'Tony Soprano',    1),
    (13, 23, 'roteirista', NULL,              1),
    (13, 21, 'ator',       'Walter White',    1),
    (13, 22, 'ator',       'Jesse Pinkman',   2),
    (14, 23, 'roteirista', NULL,              1),
    (14, 24, 'ator',       'Jimmy McGill',    1),
    ( 7, 26, 'diretor',    NULL,              1),
    ( 7, 27, 'diretor',    NULL,              2),
    ( 7, 28, 'ator',       'King Arthur',     1),
    ( 7, 29, 'ator',       'Sir Lancelot',    2),
    ( 7, 30, 'ator',       'Sir Robin',       3),
    ( 7, 31, 'ator',       'Sir Galahad',     4),
    ( 7, 27, 'ator',       'Sir Bedevere',    5),
    ( 7, 26, 'ator',       'Patsy',           6),
    (12, 32, 'diretor',    NULL,              1),
    (12, 32, 'roteirista', NULL,              1),
    (12, 33, 'ator',       'Carmela Soprano', 2),
    (12, 34, 'ator',       'Christopher Moltisanti', 3),
    (13, 23, 'diretor',    NULL,              1),
    (13, 35, 'ator',       'Skyler White',    3),
    (14, 36, 'diretor',    NULL,              1),
    (14, 36, 'roteirista', NULL,              2),
    (14, 37, 'ator',       'Kim Wexler',      2),
    (15, 25, 'diretor',    NULL,              1),
    (15, 38, 'roteirista', NULL,              1),
    (15, 39, 'ator',       'Jonas Kahnwald',  1);

-- --------------------------------------------------------- visualizacoes ---
-- Historico espalhado entre os quinze perfis. tempo_assistido_seg nunca passa
-- de duracao_min * 60, senao a RN13 recusa.
--
-- O perfil infantil (Tapa, id 12) so tem visualizacao de titulo livre, o que
-- a RN05 exige. Note que nada no banco impede o contrario: essa regra e da
-- aplicacao.
INSERT INTO visualizacao (id_perfil, id_filme, tempo_assistido_seg, dispositivo, concluiu, data_hora) VALUES
    ( 1,  1, 9240, 'tv',         TRUE,  '2026-08-02 21:10:00-03'),
    ( 1,  4, 6000, 'tv',         FALSE, '2026-08-05 22:00:00-03'),
    ( 2,  8, 6660, 'tablet',     TRUE,  '2026-08-03 19:30:00-03'),
    ( 3, 10, 7800, 'computador', TRUE,  '2026-08-11 20:15:00-03'),
    ( 4,  2, 9900, 'tv',         TRUE,  '2026-07-19 21:00:00-03'),
    ( 4,  1, 4200, 'celular',    FALSE, '2026-07-22 12:40:00-03'),
    ( 5, 11, 9600, 'tv',         TRUE,  '2026-08-20 20:00:00-03'),
    ( 6,  4,10500, 'tv',         TRUE,  '2026-06-14 21:30:00-03'),
    ( 6,  5,12120, 'tv',         TRUE,  '2026-06-21 21:30:00-03'),
    ( 6,  6, 5000, 'tv',         FALSE, '2026-06-28 21:30:00-03'),
    ( 7,  1, 9240, 'computador', TRUE,  '2026-09-01 23:00:00-03'),
    ( 7, 10, 7800, 'computador', TRUE,  '2026-09-03 23:00:00-03'),
    ( 8,  3, 8820, 'tv',         TRUE,  '2026-05-30 20:45:00-03'),
    ( 8,  7, 5460, 'tablet',     TRUE,  '2026-06-02 18:00:00-03'),
    ( 9,  9, 7020, 'console',    TRUE,  '2026-08-28 16:20:00-03'),
    (10,  2, 9900, 'tv',         TRUE,  '2026-08-15 22:10:00-03'),
    (10,  1, 9240, 'tv',         TRUE,  '2026-08-17 22:10:00-03'),
    (11,  7, 5460, 'celular',    TRUE,  '2026-08-18 13:00:00-03'),
    (12,  8, 6660, 'tv',         TRUE,  '2026-08-19 15:00:00-03'),
    (12,  9, 7020, 'tv',         TRUE,  '2026-08-25 15:30:00-03'),
    (12,  8, 3000, 'tablet',     FALSE, '2026-09-05 15:00:00-03'),
    (13,  6, 9720, 'tv',         TRUE,  '2026-07-07 21:00:00-03'),
    (14, 11, 9600, 'computador', TRUE,  '2026-08-30 19:00:00-03'),
    (15, 10, 7800, 'celular',    TRUE,  '2026-09-02 08:30:00-03');

INSERT INTO visualizacao (id_perfil, id_serie, num_temporada, num_episodio,
                          tempo_assistido_seg, dispositivo, concluiu, data_hora) VALUES
    ( 1, 13, 1, 1, 3480, 'tv',         TRUE,  '2026-08-06 20:00:00-03'),
    ( 1, 13, 1, 2, 2880, 'tv',         TRUE,  '2026-08-07 20:00:00-03'),
    ( 1, 13, 1, 3, 2880, 'tv',         TRUE,  '2026-08-08 20:00:00-03'),
    ( 2, 15, 1, 1, 3060, 'computador', TRUE,  '2026-08-09 22:30:00-03'),
    ( 2, 15, 1, 2, 2700, 'computador', TRUE,  '2026-08-10 22:30:00-03'),
    ( 3, 12, 1, 1, 3600, 'tv',         TRUE,  '2026-07-01 21:00:00-03'),
    ( 3, 12, 1, 2, 1500, 'tv',         FALSE, '2026-07-02 21:00:00-03'),
    ( 5, 14, 1, 1, 3180, 'tablet',     TRUE,  '2026-08-21 19:00:00-03'),
    ( 5, 14, 1, 2, 2820, 'tablet',     TRUE,  '2026-08-22 19:00:00-03'),
    ( 6, 13, 1, 1, 3480, 'celular',    TRUE,  '2026-06-30 07:50:00-03'),
    ( 7, 15, 1, 1, 3060, 'tv',         TRUE,  '2026-09-04 23:30:00-03'),
    ( 7, 15, 1, 2, 2700, 'tv',         TRUE,  '2026-09-05 23:30:00-03'),
    ( 7, 15, 1, 3, 3060, 'tv',         TRUE,  '2026-09-06 23:30:00-03'),
    ( 7, 15, 2, 1, 3480, 'tv',         TRUE,  '2026-09-07 23:30:00-03'),
    ( 8, 13, 1, 4, 2880, 'computador', TRUE,  '2026-06-03 18:00:00-03'),
    ( 9, 14, 1, 3, 2820, 'console',    TRUE,  '2026-08-29 16:00:00-03'),
    (10, 12, 1, 5, 3420, 'tv',         TRUE,  '2026-08-16 22:00:00-03'),
    (11, 15, 3, 8, 3840, 'computador', TRUE,  '2026-08-23 21:00:00-03'),
    (13, 12, 1, 1, 3600, 'tv',         TRUE,  '2026-07-08 21:00:00-03'),
    (13, 12, 1, 2, 3300, 'tv',         TRUE,  '2026-07-09 21:00:00-03'),
    (14, 13, 1, 1, 3480, 'tablet',     TRUE,  '2026-08-31 20:30:00-03'),
    (15, 14, 1, 1, 3180, 'celular',    TRUE,  '2026-09-03 09:00:00-03');
SELECT setval('visualizacao_id_visualizacao_seq',
              (SELECT MAX(id_visualizacao) FROM visualizacao));

COMMIT;


-- ============================================================================
-- CONSULTAS DE EXEMPLO
-- ============================================================================

-- 1. Series com o total de episodios e a duracao de cada temporada.
-- Percorre a especializacao (titulo -> serie) e as duas entidades fracas.
SELECT t.nome                  AS serie,
       tm.num_temporada        AS temporada,
       COUNT(e.num_episodio)   AS episodios,
       SUM(e.duracao_min)      AS minutos
  FROM titulo t
  JOIN serie s      ON s.id_serie = t.id_titulo
  JOIN temporada tm ON tm.id_serie = s.id_serie
  JOIN episodio e   ON e.id_serie = tm.id_serie
                   AND e.num_temporada = tm.num_temporada
 GROUP BY t.nome, tm.num_temporada
 ORDER BY t.nome, tm.num_temporada;


-- 2. Uso de cada conta: plano vigente, perfis criados e horas assistidas.
-- Percorre o nucleo de assinatura inteiro. O data_fim IS NULL dentro do JOIN
-- seleciona a assinatura vigente, e o max_perfis ao lado da contagem mostra
-- quanta folga a conta ainda tem diante da RN03.
SELECT c.nome_titular                        AS conta,
       p.nome                                AS plano,
       COUNT(DISTINCT pf.id_perfil)          AS perfis,
       p.max_perfis                          AS limite,
       ROUND(COALESCE(SUM(v.tempo_assistido_seg), 0) / 3600.0, 1) AS horas
  FROM conta c
  JOIN assinatura a ON a.id_conta = c.id_conta
                   AND a.data_fim IS NULL
  JOIN plano p      ON p.id_plano = a.id_plano
  LEFT JOIN perfil pf      ON pf.id_conta = c.id_conta
  LEFT JOIN visualizacao v ON v.id_perfil = pf.id_perfil
 GROUP BY c.nome_titular, p.nome, p.max_perfis
 ORDER BY horas DESC;


-- 3. Pessoas que acumulam mais de um papel no mesmo titulo.
-- So faz sentido porque papel faz parte da chave primaria de participacao
-- (RN11). Com a chave em (titulo, pessoa) a consulta nao teria o que agrupar.
SELECT p.nome                                     AS pessoa,
       t.nome                                     AS titulo,
       COUNT(*)                                   AS papeis,
       STRING_AGG(pa.papel, ', ' ORDER BY pa.papel) AS funcoes
  FROM participacao pa
  JOIN pessoa p ON p.id_pessoa = pa.id_pessoa
  JOIN titulo t ON t.id_titulo = pa.id_titulo
 GROUP BY p.nome, t.nome
HAVING COUNT(*) > 1
 ORDER BY papeis DESC, pessoa;
