-- ============================================================================
-- Atualizações incrementais à base de dados já existente (ronda de correções
-- depois dos primeiros testes). Corre isto UMA VEZ no SQL Editor do Supabase,
-- depois dos scripts 001 a 005 já terem sido corridos da primeira vez.
-- Usa "on conflict ... do nothing" por isso é seguro correr mesmo que algumas
-- destas chaves já existam.
-- ============================================================================

insert into configuracoes (chave, valor, categoria, tipo) values
  ('empresa_logo_url', '', 'empresa', 'texto'),
  ('home_titulo', 'GeoTrack SIG', 'pagina_inicial', 'texto'),
  ('home_subtitulo', 'Sistema de gestão de projetos de cartografia e fotogrametria da GEOLAYER — acompanhe os seus projetos, consulte relatórios e fale connosco.', 'pagina_inicial', 'texto'),
  ('home_imagem_url', '', 'pagina_inicial', 'texto'),
  ('home_descricao_imagem', '', 'pagina_inicial', 'texto'),
  ('home_creditos_imagem', '', 'pagina_inicial', 'texto')
on conflict (chave) do nothing;

-- A página inicial agora lê título/subtítulo/imagem/logótipo ANTES do login
-- (sem sessão). Sem esta política, o RLS atual bloqueava qualquer leitura de
-- "configuracoes" a quem não é administração — por isso a página inicial não
-- ia conseguir mostrar nada disto.
drop policy if exists configuracoes_leitura_publica on configuracoes;
create policy configuracoes_leitura_publica on configuracoes for select
  using (categoria = 'pagina_inicial' or chave = 'empresa_logo_url');
