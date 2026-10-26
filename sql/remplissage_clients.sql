-- 05_remplissage_clients : taux de remplissage des champs Smile candidats pour l'onglet 2-Clients du cadrage.
-- Comptages uniquement (champ renseigné ou non), aucune valeur n'est renvoyée.
-- Comptes = smile03.account (hors comptes supprimés). Champs personnalisés : clés du jsonb custom.
-- Dans pgAdmin : 1) exécuter SEULES les deux lignes set ; 2) vérifier le coût avec « explain » devant « select » ;
-- 3) exécuter la requête (de « select » à la fin) ; exporter vers data/cartographie/05_remplissage_clients.csv.

set default_transaction_read_only = on;
set statement_timeout = '5min';

-- Colonnes standard : chaque ligne est transformée en paires (champ, valeur) pour compter les champs renseignés.
-- account : colonnes listées explicitement pour ne pas déclencher le calcul des soldes de la vue.
select 'account' as source, kv.key as champ,
       count(*) filter (where nullif(trim(kv.value), '') is not null) as renseignes,
       count(*) as total
from (select usn, alternate_account_number, account_type, account_terms, account_disposition, discount,
             account_cost_centre, description, taxable, tax_schedule, currency, deactivated_time
      from smile03.account) a,
     jsonb_each_text(to_jsonb(a)) kv
group by 1, 2
union all
select 'account_contact', kv.key,
       count(*) filter (where nullif(trim(kv.value), '') is not null), count(*)
from smile03.account_contact c, jsonb_each_text(to_jsonb(c) - 'account_uuid') kv
group by 1, 2
union all
select 'account_address type ' || a.address_type, kv.key,
       count(*) filter (where nullif(trim(kv.value), '') is not null), count(*)
from smile03.account_address a, jsonb_each_text(to_jsonb(a)) kv
group by 1, 2
union all
select 'account_payment_configuration', kv.key,
       count(*) filter (where nullif(trim(kv.value), '') is not null), count(*)
from smile03.account_payment_configuration p, jsonb_each_text(to_jsonb(p)) kv
group by 1, 2

-- Champs personnalisés de compte
union all
select 'account_custom', kv.key,
       count(*) filter (where nullif(trim(kv.value), '') is not null), count(*)
from smile03.account_custom a, jsonb_each_text(a.custom) kv
group by 1, 2

-- Champs personnalisés des abonnements actifs, par service (dont Self Care : revendeur, identifiants portail)
union all
select 'subscription_custom ' || coalesce(sv.name, '?'), kv.key,
       count(*) filter (where nullif(trim(kv.value), '') is not null), count(*)
from smile03.subscription_custom s
join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
left join smile03.service sv on sv.service = s.service
cross join jsonb_each_text(s.custom) kv
where st.name in ('Active', 'Suspended')
group by 1, 2
order by 1, 2;
