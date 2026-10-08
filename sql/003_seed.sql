-- ============================================================================
-- GEOTRACK SIG — Dados de arranque / teste
-- ============================================================================

-- ---------------------------------------------------------------------------
-- CONFIGURACOES
-- ---------------------------------------------------------------------------
insert into configuracoes (chave, valor, categoria, tipo) values
  ('empresa_nome', 'GEOLAYER – Geoengenharia e Serviços, Lda', 'empresa', 'texto'),
  ('empresa_morada', 'Praça do Choupal, 19, 3050-330 Mealhada', 'empresa', 'texto'),
  ('empresa_email', 'geral@geolayer.com', 'empresa', 'texto'),
  ('empresa_footer_anexos', 'FR 52 Versão 04', 'empresa', 'texto'),
  ('empresa_fonte_pf', 'DGT / GEOLAYER', 'empresa', 'texto'),
  ('empresa_logo_url', '', 'empresa', 'texto'),

  ('home_titulo', 'GeoTrack SIG', 'pagina_inicial', 'texto'),
  ('home_subtitulo', 'Sistema de gestão de projetos de cartografia e fotogrametria da GEOLAYER — acompanhe os seus projetos, consulte relatórios e fale connosco.', 'pagina_inicial', 'texto'),
  ('home_imagem_url', '', 'pagina_inicial', 'texto'),
  ('home_descricao_imagem', '', 'pagina_inicial', 'texto'),
  ('home_creditos_imagem', '', 'pagina_inicial', 'texto'),

  ('tecnico_dgt_nome', 'Jorge Eduardo de Pinho Matos', 'responsaveis', 'texto'),
  ('tecnico_dgt_cartao_cidadao', '10770469', 'responsaveis', 'texto'),
  ('tecnico_dgt_morada_profissional', 'Praça do Choupal, 19, 3050-330 Mealhada', 'responsaveis', 'texto'),
  ('tecnico_dgt_ordem', 'Ordem dos Engenheiros Técnicos', 'responsaveis', 'texto'),
  ('tecnico_dgt_numero_inscricao', '24893', 'responsaveis', 'texto'),

  ('tecnico_campo_nome', 'Djime Dourado', 'responsaveis', 'texto'),
  ('coordenador_geolayer_defeito', 'Luís Simões', 'responsaveis', 'texto'),

  ('pf_sistema_coordenadas_defeito', 'EPSG:3763', 'parametros_pf', 'texto'),
  ('pf_mascara', '12', 'parametros_pf', 'numero'),
  ('pf_taxa_observacao', '1', 'parametros_pf', 'numero'),
  ('pf_estacao_referencia', 'Rede RENEP', 'parametros_pf', 'texto'),
  ('pf_numero_epocas', '300', 'parametros_pf', 'numero'),

  ('pf_obs_padrao_1', 'Apoio observado com recurso a pintura no asfalto.', 'parametros_pf', 'texto'),
  ('pf_obs_padrao_2', 'Apoio observado com recurso a pintura em caixa de saneamento.', 'parametros_pf', 'texto'),
  ('pf_obs_padrao_3', 'Apoio observado com recurso a alvo artificial preso ao solo.', 'parametros_pf', 'texto'),
  ('pf_obs_padrao_4', 'Apoio observado com recurso a pintura.', 'parametros_pf', 'texto'),
  ('pf_obs_padrao_5', 'Apoio observado na pintura de marcação da estrada.', 'parametros_pf', 'texto'),
  ('pf_obs_padrao_6', 'Apoio observado com recurso a pintura no solo.', 'parametros_pf', 'texto'),

  ('tema_defeito', 'claro', 'sistema', 'texto')
on conflict (chave) do nothing;

-- ---------------------------------------------------------------------------
-- EQUIPAMENTOS
-- ---------------------------------------------------------------------------
insert into equipamentos (tipo, marca, modelo, especificacoes, ativo_por_defeito) values
  ('VANT', 'DJI', 'Phantom 4 Pro', '{
     "peso_kg": 1.388,
     "autonomia_min": 30,
     "sensor": "1\" CMOS, 20MP",
     "altura_voo_recomendada_m": 120,
     "gsd_tipico_cm": 1.6
   }'::jsonb, true)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- CAOP — freguesia de exemplo (geometria simplificada, só para testar o
-- cálculo automático de distrito/concelho/freguesia; substitui pelo CAOP2024
-- real quando testares com projetos noutras zonas do país)
-- ---------------------------------------------------------------------------
insert into caop_freguesias (distrito, concelho, freguesia, codigo_caop, geom) values
  ('Aveiro', 'Mealhada', 'Mealhada', '010811',
   st_geomfromtext('MULTIPOLYGON(((-8.45 40.35, -8.35 40.35, -8.35 40.40, -8.45 40.40, -8.45 40.35)))', 4326))
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- VERSOES_DGT
-- ---------------------------------------------------------------------------
insert into versoes_dgt (versao, data_vigor_inicio, descricao) values
  ('v2.0.2', '2023-01-01', 'Especificação CartTop em vigor')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- CLIENTE + PROJETO + PFS DE TESTE
-- ---------------------------------------------------------------------------
insert into clientes (id, cliente_nome, cliente_email, cliente_cod_postal, nivel_visualizacao)
values ('00000000-0000-0000-0000-000000000001', 'Município de Teste', 'teste@exemplo.pt', '3050-330 Mealhada', 'avancado')
on conflict (id) do nothing;

insert into projetos (
  id, cliente_id, titulo, cod_geolayer, estado, geom, area, voo_area,
  voo_data, voo_altura, voo_gsd, voo_n_fotos, data_trabalhos_campo,
  coordenador_geolayer, sis_coordenadas, proj_local,
  equipamento_id
) values (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'Projeto de Teste — Praça Exemplo',
  '000000-TESTE',
  'em_curso',
  st_geomfromtext('POLYGON((-8.44 40.36, -8.43 40.36, -8.43 40.37, -8.44 40.37, -8.44 40.36))', 4326),
  4.5, 6.2,
  current_date - 30, 62.7, 1.64, 745, current_date - 30,
  'Luís Simões', 'EPSG:3763', 'Praça Exemplo',
  (select id from equipamentos where ativo_por_defeito = true limit 1)
)
on conflict (id) do nothing;

insert into pfs (projeto_id, pf_num, geom, data_observacao, hora_inicio, hora_fim,
                  n_epocas, taxa_observacao, mascara, estacao_referencia, sist_coordenadas,
                  responsavel, coord_m, coord_p, coord_z_pf, coord_z_pfsolo, observacoes)
values
  ('00000000-0000-0000-0000-000000000002', 1,
   st_geomfromtext('POINT(-8.435 40.365)', 4326),
   current_date - 30, '09:00', '09:10', 300, 1, 12, 'Rede RENEP', 'EPSG:3763',
   'Djime Dourado', 22684.976, 77027.416, 488.563, 488.563,
   'Apoio observado com recurso a pintura no solo.'),
  ('00000000-0000-0000-0000-000000000002', 2,
   st_geomfromtext('POINT(-8.433 40.367)', 4326),
   current_date - 30, '09:20', '09:30', 300, 1, 12, 'Rede RENEP', 'EPSG:3763',
   'Djime Dourado', 22732.827, 77061.589, 492.773, 492.773,
   'Apoio observado com recurso a pintura no asfalto.')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- RELATORIO_BLOCOS — exemplos (Relatório de Produção, ponto 4.4/4.5; e
-- Termo de Compromisso com as 2 variantes condicionais)
-- ---------------------------------------------------------------------------
insert into relatorio_blocos (documento, ordem, seccao_numero, seccao_titulo, nivel, tipo_bloco, conteudo, condicao, ativo) values
  ('RProducao', 10, '4', 'Trabalho de Campo e Processamento', 1, 'texto', '{"texto": ""}', null, true),
  ('RProducao', 40, '4.4', 'Realização do Voo', 2, 'texto',
   '{"texto": "O voo foi realizado a uma altura de {{projetos.voo_altura}} metros, com recurso a um veículo aéreo não tripulado (VANT), tendo sido obtidas {{projetos.voo_n_fotos}} fotografias."}', null, true),
  ('RProducao', 50, '4.5', 'Triangulação Aérea', 2, 'texto',
   '{"texto": "A triangulação aérea foi efetuada com recurso ao software Agisoft Metashape, utilizando os pontos fotogramétricos (PFs) recolhidos em campo como pontos de apoio."}', null, true),

  ('TCompromisso_CEncargos', 10, '', 'Declaração (1ª entrega)', 2, 'texto',
   '{"texto": "Eu, {{config.tecnico_dgt_nome}}, com residência profissional na {{config.tecnico_dgt_morada_profissional}}, portador do cartão de cidadão nº {{config.tecnico_dgt_cartao_cidadao}} e inscrito na {{config.tecnico_dgt_ordem}} com o nº {{config.tecnico_dgt_numero_inscricao}}, declaro que toda a informação produzida e recolhida no âmbito do processo de produção da Cartografia Topográfica Vetorial, para a elaboração do {{projetos.titulo}}, no concelho de {{projetos.proj_concelho}}, está georreferenciado e cumpre as especificações técnicas em vigor."}',
   'sem_correcao', true),
  ('TCompromisso_CEncargos', 20, '', 'Declaração (após correção DGT)', 2, 'texto',
   '{"texto": "Esta Cartografia foi corrigida de acordo com o indicado no relatório da DGT de {{projetos.data_relatorio_dgt}}, processo nº {{projetos.num_proc_dgt}}, com exceção das seguintes situações: {{projetos.dgt_erros_nao_corrigidos}}"}',
   'com_correcao', true)
on conflict do nothing;
