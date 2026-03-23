-- ============================================================
-- PROMOÇÃO DA SAÚDE — SISTEMA DE MOBILIZAÇÃO v2
-- Execute no Supabase → SQL Editor → Run
-- ============================================================

-- Tabela principal de fichas de mobilização
CREATE TABLE IF NOT EXISTS mobilizacao (
  id              BIGSERIAL PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  synced_at       TIMESTAMPTZ,

  -- Dados gerais
  provincia       TEXT NOT NULL,
  municipio       TEXT,
  comuna          TEXT,
  bairro          TEXT,
  mobilizador     TEXT NOT NULL,
  telemovel       TEXT,
  data            DATE NOT NULL,
  coordenacao     TEXT,

  -- Casa a casa
  cc_locais       INT DEFAULT 0,
  cc_pessoas      INT DEFAULT 0,
  cc_enderecos    TEXT,
  cc_obs          TEXT,

  -- Igreja
  ig_locais       INT DEFAULT 0,
  ig_pessoas      INT DEFAULT 0,
  ig_nomes        TEXT,
  ig_obs          TEXT,

  -- Praças / Mercados
  mr_locais       INT DEFAULT 0,
  mr_pessoas      INT DEFAULT 0,
  mr_nomes        TEXT,
  mr_obs          TEXT,

  -- Paragem de táxi
  tx_locais       INT DEFAULT 0,
  tx_pessoas      INT DEFAULT 0,
  tx_nomes        TEXT,
  tx_obs          TEXT,

  -- Creche
  cr_locais       INT DEFAULT 0,
  cr_pessoas      INT DEFAULT 0,
  cr_nomes        TEXT,
  cr_obs          TEXT,

  -- Escola
  ec_locais       INT DEFAULT 0,
  ec_pessoas      INT DEFAULT 0,
  ec_nomes        TEXT,
  ec_obs          TEXT,

  -- Ponto de água
  ag_locais       INT DEFAULT 0,
  ag_pessoas      INT DEFAULT 0,
  ag_nomes        TEXT,
  ag_obs          TEXT,

  -- Outros
  ot_locais       INT DEFAULT 0,
  ot_pessoas      INT DEFAULT 0,
  ot_descricao    TEXT,
  ot_obs          TEXT,

  -- Totais calculados automaticamente
  total_locais    INT GENERATED ALWAYS AS (
    cc_locais + ig_locais + mr_locais + tx_locais +
    cr_locais + ec_locais + ag_locais + ot_locais
  ) STORED,

  total_pessoas   INT GENERATED ALWAYS AS (
    cc_pessoas + ig_pessoas + mr_pessoas + tx_pessoas +
    cr_pessoas + ec_pessoas + ag_pessoas + ot_pessoas
  ) STORED,

  -- Resposta à vacinação
  vacina          TEXT CHECK (vacina IN ('sim','nao','')),
  motivo_nao      TEXT
);

-- Tabela de equipa (mobilizadores e supervisores)
CREATE TABLE IF NOT EXISTS equipa (
  id            BIGSERIAL PRIMARY KEY,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  tipo          TEXT NOT NULL CHECK (tipo IN ('mobilizador','supervisor')),
  nome          TEXT NOT NULL,
  coordenacao   TEXT,
  telefone      TEXT,
  municipio     TEXT,
  obs           TEXT
);

CREATE INDEX IF NOT EXISTS idx_equipa_tipo ON equipa (tipo);
CREATE INDEX IF NOT EXISTS idx_equipa_nome ON equipa (nome);

ALTER TABLE equipa ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_equipa" ON equipa FOR ALL USING (true) WITH CHECK (true);

-- Tabela de crianças menores de 5 anos por bairro
CREATE TABLE IF NOT EXISTS criancas_bairro (
  id              BIGSERIAL PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  bairro          TEXT NOT NULL UNIQUE,
  provincia       TEXT,
  municipio       TEXT,
  comuna          TEXT,
  total_criancas  INT DEFAULT 0,
  vacinadas       INT DEFAULT 0,
  nao_vacinadas   INT DEFAULT 0,
  data_registo    DATE,
  obs             TEXT
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_mob_data        ON mobilizacao (data DESC);
CREATE INDEX IF NOT EXISTS idx_mob_provincia   ON mobilizacao (provincia);
CREATE INDEX IF NOT EXISTS idx_mob_bairro      ON mobilizacao (bairro);
CREATE INDEX IF NOT EXISTS idx_mob_mobilizador ON mobilizacao (mobilizador);
CREATE INDEX IF NOT EXISTS idx_cri_bairro      ON criancas_bairro (bairro);

-- Row Level Security (acesso público para campanhas em campo)
ALTER TABLE mobilizacao     ENABLE ROW LEVEL SECURITY;
ALTER TABLE criancas_bairro ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_all_mob" ON mobilizacao
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_cri" ON criancas_bairro
  FOR ALL USING (true) WITH CHECK (true);

-- Função upsert de bairro (insere ou actualiza se já existir)
CREATE OR REPLACE FUNCTION upsert_criancas_bairro(
  p_bairro        TEXT,
  p_provincia     TEXT,
  p_municipio     TEXT,
  p_comuna        TEXT,
  p_total         INT,
  p_vacinadas     INT,
  p_nao_vacinadas INT,
  p_data          DATE,
  p_obs           TEXT
) RETURNS criancas_bairro AS $$
DECLARE result criancas_bairro;
BEGIN
  INSERT INTO criancas_bairro
    (bairro, provincia, municipio, comuna, total_criancas, vacinadas, nao_vacinadas, data_registo, obs, updated_at)
  VALUES
    (p_bairro, p_provincia, p_municipio, p_comuna, p_total, p_vacinadas, p_nao_vacinadas, p_data, p_obs, NOW())
  ON CONFLICT (bairro) DO UPDATE SET
    total_criancas  = EXCLUDED.total_criancas,
    vacinadas       = EXCLUDED.vacinadas,
    nao_vacinadas   = EXCLUDED.nao_vacinadas,
    provincia       = COALESCE(EXCLUDED.provincia,  criancas_bairro.provincia),
    municipio       = COALESCE(EXCLUDED.municipio,  criancas_bairro.municipio),
    comuna          = COALESCE(EXCLUDED.comuna,      criancas_bairro.comuna),
    data_registo    = EXCLUDED.data_registo,
    obs             = EXCLUDED.obs,
    updated_at      = NOW()
  RETURNING * INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Para produção com autenticação, substitui as policies acima:
-- DROP POLICY "allow_all_mob" ON mobilizacao;
-- DROP POLICY "allow_all_cri" ON criancas_bairro;
-- CREATE POLICY "auth_only_mob" ON mobilizacao
--   FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');
-- CREATE POLICY "auth_only_cri" ON criancas_bairro
--   FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');
-- ============================================================

-- ============================================================
-- POLÍTICAS DE SEGURANÇA PARA PRODUÇÃO (MOB SOC 2026)
-- Execute estas políticas DEPOIS de configurar autenticação
-- no Supabase Auth (Authentication → Users → Add user)
-- ============================================================

-- 1. Criar o utilizador supervisor no Supabase Auth:
--    Authentication → Users → Invite user
--    Email: supervisor@mobsoc.ao  (ou o email que preferires)
--    Depois define a senha manualmente

-- 2. (Opcional) Tabela de perfil estendido do supervisor
CREATE TABLE IF NOT EXISTS supervisores (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome          TEXT,
  bi            TEXT,
  telefone      TEXT,
  morada        TEXT,
  coordenacao   TEXT,
  funcao        TEXT,
  foto_url      TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE supervisores ENABLE ROW LEVEL SECURITY;

-- Supervisor só vê e edita o seu próprio perfil
CREATE POLICY "supervisor_own_profile" ON supervisores
  FOR ALL USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- POLÍTICA RECOMENDADA PARA CAMPO (sem autenticação obrigatória)
-- Mantém acesso aberto para mobilizadores em campo
-- mas protege leitura externa
-- ============================================================

-- Permitir INSERT e SELECT para todos (uso em campo offline)
-- Impede DELETE e UPDATE externos não autenticados
DROP POLICY IF EXISTS "allow_all_mob" ON mobilizacao;
DROP POLICY IF EXISTS "allow_all_cri" ON criancas_bairro;
DROP POLICY IF EXISTS "allow_all_equipa" ON equipa;

-- mobilizacao: qualquer um pode inserir e ler, só autenticados podem apagar/editar
CREATE POLICY "mob_insert_anon"  ON mobilizacao FOR INSERT WITH CHECK (true);
CREATE POLICY "mob_select_anon"  ON mobilizacao FOR SELECT USING (true);
CREATE POLICY "mob_update_auth"  ON mobilizacao FOR UPDATE  USING (auth.role()='authenticated');
CREATE POLICY "mob_delete_auth"  ON mobilizacao FOR DELETE  USING (auth.role()='authenticated');

-- criancas_bairro: mesma lógica
CREATE POLICY "cri_insert_anon"  ON criancas_bairro FOR INSERT WITH CHECK (true);
CREATE POLICY "cri_select_anon"  ON criancas_bairro FOR SELECT USING (true);
CREATE POLICY "cri_update_auth"  ON criancas_bairro FOR UPDATE  USING (auth.role()='authenticated');
CREATE POLICY "cri_delete_auth"  ON criancas_bairro FOR DELETE  USING (auth.role()='authenticated');

-- equipa: só autenticados gerem
CREATE POLICY "eq_all_auth" ON equipa
  FOR ALL USING (auth.role()='authenticated')
  WITH CHECK (auth.role()='authenticated');

-- ============================================================
-- SE PREFERIRES ACESSO TOTALMENTE ABERTO (modo campo simples)
-- descomenta as 3 linhas abaixo e comenta as políticas acima
-- ============================================================
-- CREATE POLICY "allow_all_mob" ON mobilizacao FOR ALL USING (true) WITH CHECK (true);
-- CREATE POLICY "allow_all_cri" ON criancas_bairro FOR ALL USING (true) WITH CHECK (true);
-- CREATE POLICY "allow_all_equipa" ON equipa FOR ALL USING (true) WITH CHECK (true);
