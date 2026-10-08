-- ============================================================================
-- GEOTRACK SIG — Esquema de base de dados (Supabase / PostgreSQL + PostGIS)
-- Versão de teste — gerado a partir de toda a especificação acordada.
-- Corre este ficheiro no SQL Editor do teu projeto Supabase.
-- ============================================================================

create extension if not exists postgis;
create extension if not exists pgcrypto; -- gen_random_uuid()

-- ============================================================================
-- CLIENTES
-- ============================================================================
create table if not exists clientes (
  id                  uuid primary key default gen_random_uuid(),
  cliente_nome        text not null,
  cliente_email       text,
  cliente_telefone    text,
  cliente_nif         text,
  cliente_morada      text,
  cliente_cod_postal  text,                 -- formato livre "0000-000 Localidade"
  nivel_visualizacao  text not null default 'medio'
                        check (nivel_visualizacao in ('simples','medio','avancado')),
  auth_user_id        uuid references auth.users(id) on delete set null,
  codigo_ativacao     text,                 -- usado no 1º acesso, depois anulado
  ativo               boolean not null default true,
  data_criacao        timestamptz not null default now()
);

comment on table clientes is 'Clientes da GEOLAYER. Nunca eliminar com projetos associados (ON DELETE RESTRICT aplicado via FK em projetos).';

-- ============================================================================
-- EQUIPAMENTOS (VANT + câmara, ficha técnica consolidada)
-- ============================================================================
create table if not exists equipamentos (
  id                  uuid primary key default gen_random_uuid(),
  tipo                text not null default 'VANT',
  marca               text not null,
  modelo              text not null,
  especificacoes      jsonb not null default '{}'::jsonb, -- peso, autonomia, sensor, gsd, altura_voo_recomendada, etc.
  ativo_por_defeito   boolean not null default false,
  data_criacao        timestamptz not null default now()
);

-- só pode existir um equipamento "ativo por defeito" ao mesmo tempo
create unique index if not exists equipamentos_unico_ativo_por_defeito
  on equipamentos (ativo_por_defeito)
  where ativo_por_defeito = true;

-- ============================================================================
-- PROJETOS
-- ============================================================================
create table if not exists projetos (
  id                        uuid primary key default gen_random_uuid(),
  cliente_id                uuid not null references clientes(id) on delete restrict,

  -- identificação
  titulo                    text not null,          -- NOME_CART
  cod_geolayer              text,                    -- código interno GEOLAYER
  descricao                 text,
  estado                    text not null default 'aberto'
                              check (estado in ('aberto','em_curso','concluido','atrasado','cancelado')),

  -- datas de gestão
  data_abertura             date not null default current_date,
  data_prevista_conclusao   date,
  data_conclusao            date,                    -- preenchida só ao fechar (= data real)

  -- geografia
  geom                      geometry(Geometry, 4326), -- ponto ou polígono
  proj_distrito             text[],                  -- auto, pode ter vários
  proj_concelho             text[],
  proj_freguesia            text[],
  proj_local                text,                    -- LOCAL_VOO

  -- sistema de coordenadas
  sis_coordenadas           text,                    -- ex: 'EPSG:3763'

  -- áreas
  area                      numeric,                 -- área cartografada (ha)
  voo_area                  numeric,                 -- área efetivamente voada (ha)

  -- dados de voo
  voo_data                  date,
  voo_altura                numeric,
  voo_gsd                   numeric,
  voo_n_fotos               integer,
  equipamento_id            uuid references equipamentos(id),

  -- trabalho de campo
  data_trabalhos_campo      date,

  -- responsáveis
  coordenador_geolayer      text,                    -- default vem de configuracoes, editável aqui

  -- classificação / especificações (Formulário DGT)
  finalidade_produto        text,
  tipo_cartografia          text,
  tipo_produto              text,
  temas_especificos         boolean default false,
  tipo_levantamento         text,
  especificacoes_tecnicas   text,
  versao_especificacoes     text,
  formato_dados             text,

  -- processo DGT
  num_proc_dgt              text,
  data_relatorio_dgt        date,
  dgt_data_correcao         date,
  dgt_erros_nao_corrigidos  text,

  -- anexos do relatório de produção
  anexo2_ficheiro           text,  -- storage path (relatório de voo, upload manual)
  anexo3_ficheiro           text,  -- storage path (autorização de voo, upload manual)
  -- anexo1 é o Relatório de PFs, gerado pelo próprio sistema (sem upload)

  -- dados do gráfico de execução (9 fases)
  temp_dias_planeamento         numeric,
  temp_dias_voo                 numeric,
  temp_dias_processamento       numeric,
  temp_dias_pfs                 numeric,
  temp_dias_triangulacao        numeric,
  temp_dias_restituicao         numeric,
  temp_dias_edicao_cartografica numeric,
  temp_dias_completagem         numeric,
  temp_dias_controlo_qualidade  numeric,

  ativo                     boolean not null default true,
  data_criacao              timestamptz not null default now()
);

create index if not exists projetos_cliente_id_idx on projetos (cliente_id);
create index if not exists projetos_geom_idx on projetos using gist (geom);
create index if not exists projetos_estado_idx on projetos (estado);

-- ============================================================================
-- PFS (Pontos Fotogramétricos)
-- ============================================================================
create table if not exists pfs (
  id                  uuid primary key default gen_random_uuid(),
  projeto_id          uuid not null references projetos(id) on delete cascade,

  pf_num              integer not null,       -- manual, também nome da foto

  geom                geometry(Point, 4326) not null,
  distrito            text,                    -- auto, ponto único
  concelho            text,
  freguesia           text,

  data_observacao     date,
  hora_inicio         time,                    -- cálculo automático sequencial
  hora_fim            time,

  altura_antena       numeric,
  n_epocas            integer,
  taxa_observacao     numeric,
  mascara             numeric,
  estacao_referencia  text,
  sist_coordenadas    text,
  responsavel         text,

  coord_m             numeric,
  coord_p             numeric,
  coord_z_pf          numeric,
  coord_z_pfsolo      numeric,

  observacoes         text,
  foto                text,                    -- storage path; nome = pf_num

  data_criacao        timestamptz not null default now(),

  unique (projeto_id, pf_num)
);

create index if not exists pfs_projeto_id_idx on pfs (projeto_id);
create index if not exists pfs_geom_idx on pfs using gist (geom);

-- ============================================================================
-- HISTÓRICO / AUDITORIA (acessos, alertas, notas de cliente, lembretes)
-- ============================================================================
create table if not exists historico (
  id              uuid primary key default gen_random_uuid(),
  projeto_id      uuid references projetos(id) on delete cascade,
  cliente_id      uuid references clientes(id) on delete cascade,

  tipo            text not null check (tipo in ('acesso','alerta','nota_cliente','lembrete','sistema')),
  origem          text not null default 'interno' check (origem in ('interno','cliente')),
  estado          text not null default 'pendente' check (estado in ('pendente','lido','resolvido')),

  mensagem        text,
  utilizador      text,          -- email/nome de quem gerou o registo
  sucesso         boolean,       -- usado em tentativas de login
  ip_address      text,
  user_agent      text,

  data_criacao    timestamptz not null default now()
);

create index if not exists historico_projeto_id_idx on historico (projeto_id);
create index if not exists historico_cliente_id_idx on historico (cliente_id);
create index if not exists historico_tipo_idx on historico (tipo);

-- ============================================================================
-- CONFIGURACOES (chave/valor, para definições simples)
-- ============================================================================
create table if not exists configuracoes (
  id                 uuid primary key default gen_random_uuid(),
  chave              text not null unique,
  valor              text,
  categoria          text,     -- 'empresa' | 'responsaveis' | 'parametros_pf'
  tipo               text default 'texto', -- texto|numero|boolean|data
  data_atualizacao   timestamptz not null default now()
);

-- ============================================================================
-- RELATORIO_BLOCOS (texto fixo editável, por documento, ordenável, condicional)
-- ============================================================================
create table if not exists relatorio_blocos (
  id                 uuid primary key default gen_random_uuid(),
  documento          text not null check (documento in (
                        'RProducao','TCompromisso_CEncargos','FormularioDGT',
                        'MetadadosXML','RelatorioPFs'
                     )),
  ordem              integer not null,
  seccao_numero      text,          -- rótulo impresso, ex: "4.4"
  seccao_titulo      text,
  nivel              integer not null default 2,   -- 1 = título de secção, 2 = subponto
  tipo_bloco         text not null default 'texto' check (tipo_bloco in ('texto','tabela','imagem')),
  conteudo           jsonb not null default '{}'::jsonb,
  condicao           text,          -- ex: 'num_proc_dgt_preenchido' | null = sempre
  ativo              boolean not null default true,
  data_atualizacao   timestamptz not null default now()
);

create index if not exists relatorio_blocos_doc_ordem_idx on relatorio_blocos (documento, ordem);

-- ============================================================================
-- ZONAS ANAC (restrições de voo — upload KML/GeoJSON)
-- ============================================================================
create table if not exists zonas_anac (
  id                 uuid primary key default gen_random_uuid(),
  nome               text,
  description        text,
  geom               geometry(Geometry, 4326) not null,  -- ponto ou polígono
  raio_metros        numeric,            -- só para zonas tipo ponto
  data_importacao    timestamptz not null default now()
);

create index if not exists zonas_anac_geom_idx on zonas_anac using gist (geom);

-- ============================================================================
-- CAOP — lookup administrativo + geometria simplificada p/ junção espacial
-- NOTA (teste): a junção distrito/concelho/freguesia por projeto/PF precisa de
-- geometria real por freguesia. Para já criamos a tabela com uma coluna geom
-- (MultiPolygon, simplificada/dissolvida, não a cartografia detalhada da DGT)
-- e só semeamos 1-2 freguesias de exemplo — importa o CAOP2024 completo
-- (simplificado) quando fores testar com dados reais de outras zonas.
-- ============================================================================
create table if not exists caop_freguesias (
  id                 uuid primary key default gen_random_uuid(),
  distrito           text not null,
  concelho           text not null,
  freguesia          text not null,
  codigo_caop        text,
  geom               geometry(MultiPolygon, 4326)
);

create index if not exists caop_freguesias_geom_idx on caop_freguesias using gist (geom);

-- ============================================================================
-- VERSOES_DGT (versões das especificações técnicas da DGT)
-- ============================================================================
create table if not exists versoes_dgt (
  id                 uuid primary key default gen_random_uuid(),
  versao             text not null,
  data_vigor_inicio  date,
  descricao          text
);

-- ============================================================================
-- PREFERENCIAS_UTILIZADOR (tema claro/escuro, por login, não por navegador)
-- ============================================================================
create table if not exists preferencias_utilizador (
  auth_user_id  uuid primary key references auth.users(id) on delete cascade,
  tema          text not null default 'claro' check (tema in ('claro','escuro')),
  data_atualizacao timestamptz not null default now()
);

-- ============================================================================
-- Trigger: calcular automaticamente distrito/concelho/freguesia (PFs e projetos)
-- a partir do CAOP, quando a geometria é criada/alterada.
-- ============================================================================
create or replace function fn_calcular_caop_pf() returns trigger as $$
begin
  select c.distrito, c.concelho, c.freguesia
    into new.distrito, new.concelho, new.freguesia
  from caop_freguesias c
  where st_intersects(c.geom, new.geom)
  limit 1;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_calcular_caop_pf on pfs;
create trigger trg_calcular_caop_pf
  before insert or update of geom on pfs
  for each row execute function fn_calcular_caop_pf();

create or replace function fn_calcular_caop_projeto() returns trigger as $$
begin
  select array_agg(distinct c.distrito), array_agg(distinct c.concelho), array_agg(distinct c.freguesia)
    into new.proj_distrito, new.proj_concelho, new.proj_freguesia
  from caop_freguesias c
  where st_intersects(c.geom, new.geom);
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_calcular_caop_projeto on projetos;
create trigger trg_calcular_caop_projeto
  before insert or update of geom on projetos
  for each row execute function fn_calcular_caop_projeto();

-- ============================================================================
-- Trigger: garantir só um equipamento "ativo_por_defeito" (defesa extra ao índice)
-- ============================================================================
create or replace function fn_equipamento_unico_defeito() returns trigger as $$
begin
  if new.ativo_por_defeito then
    update equipamentos set ativo_por_defeito = false where id <> new.id;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_equipamento_unico_defeito on equipamentos;
create trigger trg_equipamento_unico_defeito
  before insert or update of ativo_por_defeito on equipamentos
  for each row execute function fn_equipamento_unico_defeito();
