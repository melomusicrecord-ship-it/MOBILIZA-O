-- ============================================================
--  MOB SOC 2026 -- MOBILIZACAO SOCIAL - DNSP Angola
--  Schema completo + Politicas RLS + Funcoes + Triggers
--
--  INSTRUCOES:
--  1. supabase.com -> SQL Editor -> New Query
--  2. Cola TODO este ficheiro -> clic RUN
--  3. Copia Project URL e anon key -> config.js
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- LIMPAR POLITICAS ANTIGAS
DO $block$
BEGIN
  DROP POLICY IF EXISTS "allow_all_mob"    ON mobilizacao;
  DROP POLICY IF EXISTS "mob_anon_insert"  ON mobilizacao;
  DROP POLICY IF EXISTS "mob_anon_select"  ON mobilizacao;
  DROP POLICY IF EXISTS "mob_auth_update"  ON mobilizacao;
  DROP POLICY IF EXISTS "mob_auth_delete"  ON mobilizacao;
  DROP POLICY IF EXISTS "allow_all_cri"    ON criancas_bairro;
  DROP POLICY IF EXISTS "cri_anon_insert"  ON criancas_bairro;
  DROP POLICY IF EXISTS "cri_anon_select"  ON criancas_bairro;
  DROP POLICY IF EXISTS "cri_auth_update"  ON criancas_bairro;
  DROP POLICY IF EXISTS "cri_auth_delete"  ON criancas_bairro;
  DROP POLICY IF EXISTS "allow_all_equipa" ON equipa;
  DROP POLICY IF EXISTS "eq_anon_select"   ON equipa;
  DROP POLICY IF EXISTS "eq_auth_insert"   ON equipa;
  DROP POLICY IF EXISTS "eq_auth_update"   ON equipa;
  DROP POLICY IF EXISTS "eq_auth_delete"   ON equipa;
  DROP POLICY IF EXISTS "sup_own_select"   ON supervisores;
  DROP POLICY IF EXISTS "sup_own_insert"   ON supervisores;
  DROP POLICY IF EXISTS "sup_own_update"   ON supervisores;
EXCEPTION WHEN undefined_table THEN NULL;
END $block$;

-- ============================================================
-- TABELA 1 - mobilizacao
-- ============================================================
CREATE TABLE IF NOT EXISTS mobilizacao (
  id              BIGSERIAL    PRIMARY KEY,
  created_at      TIMESTAMPTZ  DEFAULT NOW(),
  synced_at       TIMESTAMPTZ,
  provincia       TEXT         NOT NULL,
  municipio       TEXT,
  comuna          TEXT,
  bairro          TEXT,
  coordenacao     TEXT,
  mobilizador     TEXT         NOT NULL,
  telemovel       TEXT,
  data            DATE         NOT NULL DEFAULT CURRENT_DATE,
  cc_locais       INT          DEFAULT 0,
  cc_pessoas      INT          DEFAULT 0,
  cc_enderecos    TEXT,
  cc_obs          TEXT,
  ig_locais       INT          DEFAULT 0,
  ig_pessoas      INT          DEFAULT 0,
  ig_nomes        TEXT,
  ig_obs          TEXT,
  mr_locais       INT          DEFAULT 0,
  mr_pessoas      INT          DEFAULT 0,
  mr_nomes        TEXT,
  mr_obs          TEXT,
  tx_locais       INT          DEFAULT 0,
  tx_pessoas      INT          DEFAULT 0,
  tx_nomes        TEXT,
  tx_obs          TEXT,
  cr_locais       INT          DEFAULT 0,
  cr_pessoas      INT          DEFAULT 0,
  cr_nomes        TEXT,
  cr_obs          TEXT,
  ec_locais       INT          DEFAULT 0,
  ec_pessoas      INT          DEFAULT 0,
  ec_nomes        TEXT,
  ec_obs          TEXT,
  ag_locais       INT          DEFAULT 0,
  ag_pessoas      INT          DEFAULT 0,
  ag_nomes        TEXT,
  ag_obs          TEXT,
  ot_locais       INT          DEFAULT 0,
  ot_pessoas      INT          DEFAULT 0,
  ot_descricao    TEXT,
  ot_obs          TEXT,
  total_locais    INT GENERATED ALWAYS AS (
    COALESCE(cc_locais,0)+COALESCE(ig_locais,0)+COALESCE(mr_locais,0)+
    COALESCE(tx_locais,0)+COALESCE(cr_locais,0)+COALESCE(ec_locais,0)+
    COALESCE(ag_locais,0)+COALESCE(ot_locais,0)) STORED,
  total_pessoas   INT GENERATED ALWAYS AS (
    COALESCE(cc_pessoas,0)+COALESCE(ig_pessoas,0)+COALESCE(mr_pessoas,0)+
    COALESCE(tx_pessoas,0)+COALESCE(cr_pessoas,0)+COALESCE(ec_pessoas,0)+
    COALESCE(ag_pessoas,0)+COALESCE(ot_pessoas,0)) STORED,
  vacina          TEXT         CHECK (vacina IN ('sim','nao','')),
  motivo_nao      TEXT
);
CREATE INDEX IF NOT EXISTS idx_mob_data        ON mobilizacao (data DESC);
CREATE INDEX IF NOT EXISTS idx_mob_provincia   ON mobilizacao (provincia);
CREATE INDEX IF NOT EXISTS idx_mob_municipio   ON mobilizacao (municipio);
CREATE INDEX IF NOT EXISTS idx_mob_bairro      ON mobilizacao (bairro);
CREATE INDEX IF NOT EXISTS idx_mob_mobilizador ON mobilizacao (mobilizador);
CREATE INDEX IF NOT EXISTS idx_mob_created     ON mobilizacao (created_at DESC);

-- ============================================================
-- TABELA 2 - criancas_bairro
-- ============================================================
CREATE TABLE IF NOT EXISTS criancas_bairro (
  id              BIGSERIAL    PRIMARY KEY,
  created_at      TIMESTAMPTZ  DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  DEFAULT NOW(),
  bairro          TEXT         NOT NULL UNIQUE,
  provincia       TEXT,
  municipio       TEXT,
  comuna          TEXT,
  total_criancas  INT          DEFAULT 0,
  vacinadas       INT          DEFAULT 0,
  nao_vacinadas   INT          DEFAULT 0,
  data_registo    DATE,
  obs             TEXT
);
CREATE INDEX IF NOT EXISTS idx_cri_bairro    ON criancas_bairro (bairro);
CREATE INDEX IF NOT EXISTS idx_cri_municipio ON criancas_bairro (municipio);

-- ============================================================
-- TABELA 3 - equipa
-- ============================================================
CREATE TABLE IF NOT EXISTS equipa (
  id              BIGSERIAL    PRIMARY KEY,
  created_at      TIMESTAMPTZ  DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  DEFAULT NOW(),
  tipo            TEXT         NOT NULL CHECK (tipo IN ('mobilizador','supervisor')),
  nome            TEXT         NOT NULL,
  coordenacao     TEXT,
  telefone        TEXT,
  municipio       TEXT,
  obs             TEXT
);
CREATE INDEX IF NOT EXISTS idx_equipa_tipo ON equipa (tipo);
CREATE INDEX IF NOT EXISTS idx_equipa_nome ON equipa (nome);

-- ============================================================
-- TABELA 4 - supervisores (perfil ligado ao Auth)
-- ============================================================
CREATE TABLE IF NOT EXISTS supervisores (
  id              UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ  DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  DEFAULT NOW(),
  nome            TEXT,
  bi              TEXT,
  telefone        TEXT,
  morada          TEXT,
  coordenacao     TEXT,
  funcao          TEXT,
  foto_url        TEXT
);

-- ============================================================
-- ACTIVAR RLS
-- ============================================================
ALTER TABLE mobilizacao     ENABLE ROW LEVEL SECURITY;
ALTER TABLE criancas_bairro ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipa           ENABLE ROW LEVEL SECURITY;
ALTER TABLE supervisores     ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLITICAS - mobilizacao
--   INSERT + SELECT : aberto (campo offline)
--   UPDATE + DELETE : so supervisor autenticado
-- ============================================================
CREATE POLICY "mob_anon_insert" ON mobilizacao FOR INSERT WITH CHECK (true);
CREATE POLICY "mob_anon_select" ON mobilizacao FOR SELECT USING (true);
CREATE POLICY "mob_auth_update" ON mobilizacao FOR UPDATE
  USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');
CREATE POLICY "mob_auth_delete" ON mobilizacao FOR DELETE
  USING (auth.role()='authenticated');

-- ============================================================
-- POLITICAS - criancas_bairro
-- ============================================================
CREATE POLICY "cri_anon_insert" ON criancas_bairro FOR INSERT WITH CHECK (true);
CREATE POLICY "cri_anon_select" ON criancas_bairro FOR SELECT USING (true);
CREATE POLICY "cri_auth_update" ON criancas_bairro FOR UPDATE
  USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');
CREATE POLICY "cri_auth_delete" ON criancas_bairro FOR DELETE
  USING (auth.role()='authenticated');

-- ============================================================
-- POLITICAS - equipa
--   SELECT : aberto
--   INSERT / UPDATE / DELETE : so autenticados
-- ============================================================
CREATE POLICY "eq_anon_select" ON equipa FOR SELECT USING (true);
CREATE POLICY "eq_auth_insert" ON equipa FOR INSERT
  WITH CHECK (auth.role()='authenticated');
CREATE POLICY "eq_auth_update" ON equipa FOR UPDATE
  USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');
CREATE POLICY "eq_auth_delete" ON equipa FOR DELETE
  USING (auth.role()='authenticated');

-- ============================================================
-- POLITICAS - supervisores
--   Cada supervisor acede apenas ao seu proprio perfil
-- ============================================================
CREATE POLICY "sup_own_select" ON supervisores FOR SELECT USING (auth.uid()=id);
CREATE POLICY "sup_own_insert" ON supervisores FOR INSERT WITH CHECK (auth.uid()=id);
CREATE POLICY "sup_own_update" ON supervisores FOR UPDATE
  USING (auth.uid()=id) WITH CHECK (auth.uid()=id);

-- ============================================================
-- FUNCAO - upsert_criancas_bairro
-- ============================================================
CREATE OR REPLACE FUNCTION upsert_criancas_bairro(
  p_bairro TEXT, p_provincia TEXT, p_municipio TEXT, p_comuna TEXT,
  p_total INT, p_vacinadas INT, p_nao_vacinadas INT, p_data DATE, p_obs TEXT
) RETURNS criancas_bairro LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE result criancas_bairro;
BEGIN
  INSERT INTO criancas_bairro (bairro,provincia,municipio,comuna,
    total_criancas,vacinadas,nao_vacinadas,data_registo,obs,updated_at)
  VALUES (p_bairro,p_provincia,p_municipio,p_comuna,
    p_total,p_vacinadas,p_nao_vacinadas,p_data,p_obs,NOW())
  ON CONFLICT (bairro) DO UPDATE SET
    total_criancas=EXCLUDED.total_criancas, vacinadas=EXCLUDED.vacinadas,
    nao_vacinadas=EXCLUDED.nao_vacinadas,
    provincia=COALESCE(EXCLUDED.provincia,criancas_bairro.provincia),
    municipio=COALESCE(EXCLUDED.municipio,criancas_bairro.municipio),
    comuna=COALESCE(EXCLUDED.comuna,criancas_bairro.comuna),
    data_registo=EXCLUDED.data_registo, obs=EXCLUDED.obs, updated_at=NOW()
  RETURNING * INTO result;
  RETURN result;
END; $$;

-- ============================================================
-- FUNCAO - estatisticas_campanha
--   Uso: SELECT * FROM estatisticas_campanha();
-- ============================================================
CREATE OR REPLACE FUNCTION estatisticas_campanha()
RETURNS TABLE(total_fichas BIGINT, total_pessoas BIGINT, total_locais BIGINT,
  total_bairros BIGINT, total_mobilizadores BIGINT, fichas_hoje BIGINT,
  aceitam_vacina BIGINT, recusam_vacina BIGINT, pct_aceitacao NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN QUERY SELECT
  COUNT(*),
  COALESCE(SUM(m.total_pessoas),0)::BIGINT,
  COALESCE(SUM(m.total_locais),0)::BIGINT,
  COUNT(DISTINCT m.bairro)::BIGINT,
  COUNT(DISTINCT m.mobilizador)::BIGINT,
  COUNT(*) FILTER (WHERE m.data=CURRENT_DATE),
  COUNT(*) FILTER (WHERE m.vacina='sim'),
  COUNT(*) FILTER (WHERE m.vacina='nao'),
  CASE WHEN COUNT(*) FILTER (WHERE m.vacina IN ('sim','nao'))>0
    THEN ROUND(COUNT(*) FILTER (WHERE m.vacina='sim')::NUMERIC
         /COUNT(*) FILTER (WHERE m.vacina IN ('sim','nao'))*100,1)
    ELSE 0 END
FROM mobilizacao m; END; $$;

-- ============================================================
-- FUNCAO - ranking_mobilizadores
--   Uso: SELECT * FROM ranking_mobilizadores('pessoas');
--        SELECT * FROM ranking_mobilizadores('locais');
--        SELECT * FROM ranking_mobilizadores('fichas');
-- ============================================================
CREATE OR REPLACE FUNCTION ranking_mobilizadores(p_ordem TEXT DEFAULT 'pessoas')
RETURNS TABLE(posicao INT, mobilizador TEXT, total_fichas BIGINT,
  total_pessoas BIGINT, total_locais BIGINT, total_bairros BIGINT,
  aceitam_vacina BIGINT, pct_aceitacao NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN QUERY SELECT
  ROW_NUMBER() OVER (ORDER BY CASE p_ordem
    WHEN 'locais' THEN SUM(m.total_locais)
    WHEN 'fichas' THEN COUNT(*)
    ELSE SUM(m.total_pessoas) END DESC)::INT,
  m.mobilizador, COUNT(*)::BIGINT,
  COALESCE(SUM(m.total_pessoas),0)::BIGINT,
  COALESCE(SUM(m.total_locais),0)::BIGINT,
  COUNT(DISTINCT m.bairro)::BIGINT,
  COUNT(*) FILTER (WHERE m.vacina='sim')::BIGINT,
  CASE WHEN COUNT(*) FILTER (WHERE m.vacina IN ('sim','nao'))>0
    THEN ROUND(COUNT(*) FILTER (WHERE m.vacina='sim')::NUMERIC
         /COUNT(*) FILTER (WHERE m.vacina IN ('sim','nao'))*100,1)
    ELSE 0 END
FROM mobilizacao m GROUP BY m.mobilizador; END; $$;

-- ============================================================
-- FUNCAO - resumo_por_bairro
--   Uso: SELECT * FROM resumo_por_bairro();
-- ============================================================
CREATE OR REPLACE FUNCTION resumo_por_bairro()
RETURNS TABLE(bairro TEXT, provincia TEXT, municipio TEXT,
  total_fichas BIGINT, total_pessoas BIGINT, total_locais BIGINT,
  mobilizadores TEXT, ultima_data DATE)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN QUERY SELECT
  m.bairro, MAX(m.provincia), MAX(m.municipio), COUNT(*)::BIGINT,
  COALESCE(SUM(m.total_pessoas),0)::BIGINT,
  COALESCE(SUM(m.total_locais),0)::BIGINT,
  STRING_AGG(DISTINCT m.mobilizador,', '), MAX(m.data)
FROM mobilizacao m WHERE m.bairro IS NOT NULL AND m.bairro<>''
GROUP BY m.bairro ORDER BY total_pessoas DESC; END; $$;

-- ============================================================
-- TRIGGER - updated_at automatico
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at=NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_equipa_updated       ON equipa;
DROP TRIGGER IF EXISTS trg_supervisores_updated ON supervisores;
DROP TRIGGER IF EXISTS trg_criancas_updated     ON criancas_bairro;
CREATE TRIGGER trg_equipa_updated       BEFORE UPDATE ON equipa
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_supervisores_updated BEFORE UPDATE ON supervisores
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_criancas_updated     BEFORE UPDATE ON criancas_bairro
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- VERIFICACAO FINAL
-- Confirmar tabelas:
--   SELECT table_name FROM information_schema.tables
--   WHERE table_schema='public' ORDER BY table_name;
-- Confirmar politicas:
--   SELECT tablename,policyname,cmd FROM pg_policies
--   WHERE schemaname='public' ORDER BY tablename,policyname;
-- Confirmar funcoes:
--   SELECT routine_name FROM information_schema.routines
--   WHERE routine_schema='public' ORDER BY routine_name;
-- ============================================================
