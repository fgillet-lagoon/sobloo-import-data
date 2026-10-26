-- 06_profil_clients : formats et répartitions des champs clients, pour fixer les règles de l'onglet 2-Clients.
-- Aucune valeur n'est renvoyée : seulement des masques (chiffre → 9, lettre → A), des valeurs oui/non et des comptages.
-- Dans pgAdmin : 1) exécuter SEULES les deux lignes set ; 2) vérifier le coût avec « explain » devant « with » ;
-- 3) exécuter la requête (de « with » à la fin) ; exporter vers data/cartographie/06_profil_clients.csv.

set default_transaction_read_only = on;
set statement_timeout = '5min';

-- Masque d'une valeur : chiffres → 9, lettres → A, autres caractères conservés (espaces, tirets, points…)
with selfcare as (
    select s.custom
    from smile03.subscription_custom s
    join smile03.service sv on sv.service = s.service and sv.name = 'Self Care (CAT)'
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    where st.name in ('Active', 'Suspended')
)

-- RIB (n° 58-61) : format par type de paiement
select 'rib card_number' as mesure, coalesce(pt.name, '?') || ' | ' ||
       regexp_replace(regexp_replace(c.card_number, '[0-9]', '9', 'g'), '[A-Za-z]', 'A', 'g') as valeur, count(*) as nombre
from smile03.account_payment_configuration c
left join smile03.payment_type pt on pt.payment_type = c.payment_type
group by 2
union all
select 'rib branch_number', coalesce(pt.name, '?') || ' | ' ||
       coalesce(regexp_replace(regexp_replace(c.branch_number, '[0-9]', '9', 'g'), '[A-Za-z]', 'A', 'g'), '(vide)'), count(*)
from smile03.account_payment_configuration c
left join smile03.payment_type pt on pt.payment_type = c.payment_type
group by 2

-- RIDET (n° 9) et téléphones (n° 17-18) : longueur en chiffres
union all
select 'ridet abn', regexp_replace(regexp_replace(abn, '[0-9]', '9', 'g'), '[A-Za-z]', 'A', 'g'), count(*)
from smile03.account_contact
where nullif(trim(abn), '') is not null
group by 2
union all
select 'phone_mobile chiffres', length(regexp_replace(phone_mobile, '\D', '', 'g'))::text, count(*)
from smile03.account_contact
where nullif(trim(phone_mobile), '') is not null
group by 2
union all
select 'phone_home chiffres', length(regexp_replace(phone_home, '\D', '', 'g'))::text, count(*)
from smile03.account_contact
where nullif(trim(phone_home), '') is not null
group by 2

-- E-mail (n° 16) : format invalide et doublons
union all
select 'email', 'format invalide', count(*)
from smile03.account_contact
where nullif(trim(email_address), '') is not null
  and email_address !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
union all
select 'email', 'adresses partagées par plusieurs comptes (lignes en trop)', count(*) - count(distinct lower(trim(email_address)))
from smile03.account_contact
where nullif(trim(email_address), '') is not null

-- Unicité (n° 21 loyalty_card, n° 9 RIDET)
union all
select 'ConsoPlusID', 'doublons (lignes en trop)', count(*) - count(distinct a.custom ->> 'ConsoPlusID')
from smile03.account_custom a
where nullif(trim(a.custom ->> 'ConsoPlusID'), '') is not null
union all
select 'ridet abn', 'doublons (lignes en trop)', count(*) - count(distinct trim(abn))
from smile03.account_contact
where nullif(trim(abn), '') is not null

-- Adresses types 0 et 1 (cas 6) : identiques ou différentes ?
union all
select 'adresses 0 vs 1', case
         when a0.address_detail is not distinct from a1.address_detail
          and a0.suburb is not distinct from a1.suburb
          and a0.postcode is not distinct from a1.postcode then 'identiques'
         else 'différentes' end, count(*)
from smile03.account_address a0
join smile03.account_address a1 on a1.account = a0.account and a1.address_type = 1
where a0.address_type = 0
group by 2

-- Comptes délégués (n° 27), taxes (n° 48-49)
union all
select 'comptes délégués', '', count(*)
from smile03.account
where delegate_account_uuid is not null
union all
select 'taxable / tax_schedule', a.taxable::text || ' / ' || coalesce(a.tax_schedule::text, '?'), count(*)
from smile03.account a
group by 2

-- Valeurs des indicateurs : seules les valeurs de type oui/non sont affichées, toute autre valeur est masquée
union all
select 'selfcare retailerAccount', case when lower(trim(custom ->> 'retailerAccount')) in ('true', 'false', 'oui', 'non', 'yes', 'no', '0', '1', '') then lower(trim(custom ->> 'retailerAccount')) else '(autre valeur)' end, count(*)
from selfcare
where custom ? 'retailerAccount'
group by 2
union all
select 'selfcare limited_access', case when lower(trim(custom ->> 'limited_access')) in ('true', 'false', 'oui', 'non', 'yes', 'no', '0', '1', '') then lower(trim(custom ->> 'limited_access')) else '(autre valeur)' end, count(*)
from selfcare
where custom ? 'limited_access'
group by 2
union all
select 'Procuration_', case when lower(trim(a.custom ->> 'Procuration_')) in ('true', 'false', 'oui', 'non', 'yes', 'no', '0', '1', '') then lower(trim(a.custom ->> 'Procuration_')) else '(autre valeur)' end, count(*)
from smile03.account_custom a
where a.custom ? 'Procuration_'
group by 2
order by 1, 3 desc;
