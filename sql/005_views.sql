-- ============================================================================
-- Views para o mapa: o PostgREST (motor por trás do cliente supabase-js) não
-- converte a coluna "geometry" do PostGIS para GeoJSON automaticamente — devolve
-- o valor em WKB (ilegível no frontend). Estas views já expõem a geometria
-- como texto GeoJSON (geom_geojson), prontas a usar com L.geoJSON(JSON.parse(...)).
-- As políticas de RLS da tabela original aplicam-se também à view.
-- ============================================================================

create or replace view projetos_mapa as
select p.*, st_asgeojson(p.geom) as geom_geojson
from projetos p;

create or replace view pfs_mapa as
select f.*, st_asgeojson(f.geom) as geom_geojson
from pfs f;

create or replace view zonas_anac_mapa as
select z.*, st_asgeojson(z.geom) as geom_geojson
from zonas_anac z;

-- as views herdam o RLS das tabelas de origem, mas o Supabase só expõe via
-- API o que tiver GRANT explícito às roles usadas pelo PostgREST:
grant select on projetos_mapa to authenticated;
grant select on pfs_mapa to authenticated;
grant select on zonas_anac_mapa to authenticated;
