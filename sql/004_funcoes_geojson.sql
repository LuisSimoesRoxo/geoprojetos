-- ============================================================================
-- Funções auxiliares: o cliente supabase-js não converte GeoJSON para o tipo
-- geometry do PostGIS automaticamente (só entende WKT/EWKT em texto simples).
-- Estas funções RPC recebem o GeoJSON tal como o Leaflet.draw ou o
-- conversor KML->GeoJSON o produzem, e fazem a conversão no lado da BD.
-- ============================================================================

create or replace function guardar_geom_projeto(id_projeto uuid, geojson text)
returns void as $$
begin
  update projetos
  set geom = st_setsrid(st_geomfromgeojson(geojson), 4326)
  where id = id_projeto;
end;
$$ language plpgsql security invoker;

create or replace function importar_zona_anac(p_nome text, p_description text, p_geojson text, p_raio_metros numeric default null)
returns uuid as $$
declare novo_id uuid;
begin
  insert into zonas_anac (nome, description, geom, raio_metros)
  values (p_nome, p_description, st_setsrid(st_geomfromgeojson(p_geojson), 4326), p_raio_metros)
  returning id into novo_id;
  return novo_id;
end;
$$ language plpgsql security invoker;

-- Devolve a geometria de um projeto já como GeoJSON, para desenhar no mapa
-- ao abrir a página de edição.
create or replace function obter_geom_projeto_geojson(id_projeto uuid)
returns text as $$
  select st_asgeojson(geom) from projetos where id = id_projeto;
$$ language sql stable;
