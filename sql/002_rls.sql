-- ============================================================================
-- GEOTRACK SIG — Row Level Security
-- ============================================================================
-- "Administração" = qualquer utilizador autenticado com email @geolayer.com.
-- Se um dia houver staff com outro domínio de email, troca esta função por
-- uma tabela "administradores" com a lista de auth_user_id.
-- ============================================================================
create or replace function fn_is_admin() returns boolean as $$
  select coalesce( (auth.jwt() ->> 'email') ilike '%@geolayer.com', false );
$$ language sql stable;

create or replace function fn_cliente_id_atual() returns uuid as $$
  select id from clientes where auth_user_id = auth.uid();
$$ language sql stable;

-- ---------------------------------------------------------------------------
alter table clientes enable row level security;
drop policy if exists clientes_admin_all on clientes;
create policy clientes_admin_all on clientes for all
  using (fn_is_admin()) with check (fn_is_admin());
drop policy if exists clientes_proprio on clientes;
create policy clientes_proprio on clientes for select
  using (auth_user_id = auth.uid());

-- ---------------------------------------------------------------------------
alter table projetos enable row level security;
drop policy if exists projetos_admin_all on projetos;
create policy projetos_admin_all on projetos for all
  using (fn_is_admin()) with check (fn_is_admin());
drop policy if exists projetos_cliente_select on projetos;
create policy projetos_cliente_select on projetos for select
  using (cliente_id = fn_cliente_id_atual());

-- ---------------------------------------------------------------------------
alter table pfs enable row level security;
drop policy if exists pfs_admin_all on pfs;
create policy pfs_admin_all on pfs for all
  using (fn_is_admin()) with check (fn_is_admin());
drop policy if exists pfs_cliente_select on pfs;
create policy pfs_cliente_select on pfs for select
  using (projeto_id in (select id from projetos where cliente_id = fn_cliente_id_atual()));

-- ---------------------------------------------------------------------------
alter table historico enable row level security;
drop policy if exists historico_admin_all on historico;
create policy historico_admin_all on historico for all
  using (fn_is_admin()) with check (fn_is_admin());
-- cliente só vê notas/lembretes dos seus próprios projetos/cliente
drop policy if exists historico_cliente_select on historico;
create policy historico_cliente_select on historico for select
  using (
    cliente_id = fn_cliente_id_atual()
    and tipo in ('nota_cliente','lembrete')
  );
-- cliente só pode criar notas suas, com origem='cliente'
drop policy if exists historico_cliente_insert on historico;
create policy historico_cliente_insert on historico for insert
  with check (
    cliente_id = fn_cliente_id_atual()
    and tipo = 'nota_cliente'
    and origem = 'cliente'
  );

-- ---------------------------------------------------------------------------
-- Só administração: configuracoes, relatorio_blocos, equipamentos,
-- zonas_anac, caop_freguesias, versoes_dgt
-- ---------------------------------------------------------------------------
alter table configuracoes enable row level security;
drop policy if exists configuracoes_admin_all on configuracoes;
create policy configuracoes_admin_all on configuracoes for all
  using (fn_is_admin()) with check (fn_is_admin());
-- a página inicial (pública, antes de qualquer login) mostra título, subtítulo,
-- imagem e logótipo — por isso só estas chaves, nada sensível, podem ser lidas
-- sem sessão. Tudo o resto de configuracoes continua só para administração.
drop policy if exists configuracoes_leitura_publica on configuracoes;
create policy configuracoes_leitura_publica on configuracoes for select
  using (categoria = 'pagina_inicial' or chave = 'empresa_logo_url');

alter table relatorio_blocos enable row level security;
drop policy if exists relatorio_blocos_admin_all on relatorio_blocos;
create policy relatorio_blocos_admin_all on relatorio_blocos for all
  using (fn_is_admin()) with check (fn_is_admin());

alter table equipamentos enable row level security;
drop policy if exists equipamentos_admin_all on equipamentos;
create policy equipamentos_admin_all on equipamentos for all
  using (fn_is_admin()) with check (fn_is_admin());

alter table zonas_anac enable row level security;
drop policy if exists zonas_anac_admin_all on zonas_anac;
create policy zonas_anac_admin_all on zonas_anac for all
  using (fn_is_admin()) with check (fn_is_admin());
-- zonas ANAC podem ser lidas por todos os autenticados (para desenhar no mapa do cliente)
drop policy if exists zonas_anac_leitura_geral on zonas_anac;
create policy zonas_anac_leitura_geral on zonas_anac for select
  using (auth.uid() is not null);

alter table caop_freguesias enable row level security;
drop policy if exists caop_admin_all on caop_freguesias;
create policy caop_admin_all on caop_freguesias for all
  using (fn_is_admin()) with check (fn_is_admin());

alter table versoes_dgt enable row level security;
drop policy if exists versoes_dgt_admin_all on versoes_dgt;
create policy versoes_dgt_admin_all on versoes_dgt for all
  using (fn_is_admin()) with check (fn_is_admin());

-- ---------------------------------------------------------------------------
alter table preferencias_utilizador enable row level security;
drop policy if exists preferencias_proprio on preferencias_utilizador;
create policy preferencias_proprio on preferencias_utilizador for all
  using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- NOTA sobre restrição por nível de visualização (Simples/Médio/Avançado):
-- O RLS acima é ao nível da LINHA (um cliente só vê os projetos dele).
-- A restrição de que CAMPOS dentro desse projeto são mostrados a um cliente
-- "Simples" vs "Avançado" é feita no frontend (public/js/visibilidade.js),
-- porque PostgreSQL RLS não filtra colunas individualmente de forma simples.
-- ============================================================================
