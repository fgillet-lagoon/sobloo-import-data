-- Cartographie de la base Smile (lagoon.nc) : structure et volumes uniquement, aucune donnée client.
-- Cadrage : préalable à tous les onglets ; cas limites 24 (sources) et 25 (volumétrie).
-- Dans pgAdmin, exécuter chaque requête séparément (sélectionner puis F5) et exporter le résultat en CSV
-- vers data/cartographie/<numéro>_<nom>.csv.

-- 01_tables : tables et vues, volume estimé, taille, commentaire
select n.nspname as schema,
       c.relname as table_name,
       case c.relkind when 'r' then 'table' when 'p' then 'table partitionnée'
                      when 'v' then 'vue' when 'm' then 'vue matérialisée' end as type,
       coalesce(s.n_live_tup, greatest(c.reltuples, 0)::bigint) as nb_lignes_estime,
       pg_size_pretty(pg_total_relation_size(c.oid)) as taille,
       obj_description(c.oid, 'pg_class') as commentaire
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_stat_user_tables s on s.relid = c.oid
where c.relkind in ('r', 'p', 'v', 'm')
  and n.nspname not in ('pg_catalog', 'information_schema')
  and n.nspname not like 'pg_toast%'
order by schema, nb_lignes_estime desc nulls last;

-- 02_colonnes : colonnes de toutes les tables, type, obligatoire, défaut, commentaire
select c.table_schema as schema,
       c.table_name,
       c.ordinal_position as position,
       c.column_name,
       c.data_type,
       c.character_maximum_length as longueur_max,
       c.is_nullable as nullable,
       c.column_default as defaut,
       col_description(format('%I.%I', c.table_schema, c.table_name)::regclass, c.ordinal_position) as commentaire
from information_schema.columns c
where c.table_schema not in ('pg_catalog', 'information_schema')
order by schema, c.table_name, position;

-- 03_contraintes : clés primaires, unicités et clés étrangères (liens entre tables)
select con.conrelid::regclass as table_name,
       case con.contype when 'p' then 'clé primaire' when 'u' then 'unique' when 'f' then 'clé étrangère' end as type,
       con.conname as contrainte,
       con.confrelid::regclass as table_cible,
       pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_namespace n on n.oid = con.connamespace
where con.contype in ('p', 'u', 'f')
  and n.nspname not in ('pg_catalog', 'information_schema')
order by 1, 2, 3;
