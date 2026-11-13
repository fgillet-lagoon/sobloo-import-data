-- Export clients de test (onglet 2-Clients) : uniquement les clients ayant un abonnement à reprendre
-- avec la réduction « -100% Employés Lagoon » (planoption 610, altop / emplo) en cours. Demande Lagoon du 13/11/2026.
-- Une ligne par client (customer.ref = account.usn). Valeurs Smile brutes : la normalisation (téléphones…) est faite par l'import So'Bloo.
-- Hors export : RIB et mandats SEPA (déjà dans So'Bloo), mots de passe.
-- DONNÉES PERSONNELLES : sortie dans data/clients/ (non versionné), ne jamais transmettre hors dépôt So'Bloo.
-- Lancer depuis la racine du dépôt : psql -X -v ON_ERROR_STOP=1 -f sql/export_clients_test.sql
\pset format csv
\pset footer off
\set reduction_test 610
\! mkdir -p data/clients
\o data/clients/2_clients_test_employes.csv

with pec as (  -- ligne de plan en cours de chaque abonnement (mêmes règles que sql/perimetre.sql)
    select distinct on (i.uid) i.uid as subscription, i.psi, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
abonnements as (
    select s.subscription, s.account, pec.psi, coalesce(sv.name, '') as service, st.name as statut, pec.plan
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    join pec on pec.subscription = s.subscription
),
a_reprendre as (
    select * from abonnements
    where statut in ('Active', 'Suspended') and service <> 'Self Care (CAT)' and plan not in ('closed', 'inactive')
),
clients as (
    select distinct a.account
    from a_reprendre a join public.planscheduleoption o on o.psi = a.psi
    where o.planoption = :reduction_test
),
selfcare as (  -- indicateurs portés par l'abonnement Self Care du client
    select sc.account,
           bool_or(lower(trim(sc.custom ->> 'limited_access')) = 'true') as acces_limite,
           bool_or(lower(trim(sc.custom ->> 'retailerAccount')) = 'true') as revendeur
    from smile03.subscription_custom sc
    join abonnements a on a.subscription = sc.subscription
    where a.service = 'Self Care (CAT)' and a.statut in ('Active', 'Suspended')
    group by sc.account
),
paiement as (
    select distinct on (c.account) c.account, pt.name as type_paiement
    from smile03.account_payment_configuration c
    left join smile03.payment_type pt on pt.payment_type = c.payment_type
    order by c.account, c.account_payment_option desc nulls last
),
nb as (select account, count(*) as n from a_reprendre group by 1),
-- Champs personnalisés du compte : texte, liste ou objet référencé (CE, commercial) selon le compte. Mis à plat en texte,
-- valeurs d'une liste séparées par « | », objet = son libellé (value.objectName).
champs as (
    select c.account, k.key,
           nullif(trim(string_agg(case jsonb_typeof(e.v) when 'object' then coalesce(e.v -> 'value' ->> 'objectName', e.v ->> 'code')
                                                          else e.v #>> '{}' end, ' | ')), '') as valeur
    from clients c
    join smile03.account_custom ac on ac.account = c.account
    cross join lateral jsonb_each(ac.custom) k
    cross join lateral (select x from jsonb_array_elements(case jsonb_typeof(k.value) when 'array' then k.value end) x
                        union all select k.value where jsonb_typeof(k.value) <> 'array') e(v)
    where k.key in ('lieu_naissance', 'ConsoPlusID', 'profession', 'nomduce', 'Procuration_', 'Commercial', 'comments')
    group by 1, 2
),
perso as (select account, jsonb_object_agg(key, valeur) as v from champs where valeur is not null group by 1)
select ac.usn as "customer.ref",
       nullif(trim(ac.alternate_account_number), '') as "ancien numéro de compte Smile",
       aty.name as "type de compte Smile",
       case when aty.name = 'Particulier' then 'Particulier'
            when aty.name = 'Contentieux' and nullif(trim(ct.company_name), '') is null then 'Particulier'
            else 'Société' end as "customer.person_type",
       nullif(trim(ct.contact_title), '') as "customer.title",
       ct.gender as "genre Smile",
       ct.family_name as "customer.last_name",
       ct.given_name as "customer.first_name",
       nullif(trim(ct.company_name), '') as "customer.label",
       nullif(trim(ct.trading_name), '') as "customer.acronym",
       nullif(trim(ct.abn), '') as "customer.ridet",
       ct.date_of_birth as "customer.birth_date",
       pe.v ->> 'lieu_naissance' as "customer.place_of_birth",
       pe.v ->> 'ConsoPlusID' as "customer.loyalty_card",
       'Non' as "customer.is_prospect",
       pe.v ->> 'profession' as "customer.occupation",
       pe.v ->> 'nomduce' as "groupe CE (nomduce)",
       nullif(trim(ct.email_address), '') as "customer.email",
       coalesce(nullif(trim(ct.phone_home), ''), nullif(trim(ct.phone_work), '')) as "customer.phone_number",
       nullif(trim(ct.phone_mobile), '') as "customer.mobile_phone_number",
       nullif(trim(ct.fax), '') as "customer.fax",
       a0.address_name as "adresse 0 : libellé", a0.address_detail as "adresse 0 : ligne 1", a0.suburb as "adresse 0 : ville",
       a0.postcode as "adresse 0 : code postal", coalesce(nullif(trim(a0.country), ''), 'Nouvelle-Calédonie') as "adresse 0 : pays",
       a1.address_name as "adresse 1 : libellé", a1.address_detail as "adresse 1 : ligne 1", a1.suburb as "adresse 1 : ville",
       a1.postcode as "adresse 1 : code postal", coalesce(nullif(trim(a1.country), ''), 'Nouvelle-Calédonie') as "adresse 1 : pays",
       (row(a0.address_name, a0.address_detail, a0.suburb, a0.postcode) is not distinct from
        row(a1.address_name, a1.address_detail, a1.suburb, a1.postcode)) as "adresses 0 et 1 identiques",
       pe.v ->> 'Procuration_' as "contact avec procuration",
       ast.name as "statut du compte Smile",
       di.name as "disposition Smile (recouvrement)",
       coalesce(sc.acces_limite, false) as "accès limité",
       coalesce(sc.revendeur, false) as "revendeur",
       ac.taxable as "taxable", ac.tax_schedule as "barème de taxe",
       te.name as "conditions de paiement Smile", 1 as "settlement_period (mois)",
       p.type_paiement as "type de paiement privilégié",
       'Débit' as "payment_profile.type",
       ac.currency as "devise",
       pe.v ->> 'Commercial' as "commercial",
       pe.v ->> 'comments' as "note client",
       nb.n as "abonnements à reprendre"
from clients c
join smile03.account_custom ac on ac.account = c.account
left join smile03.account_type aty on aty.account_type = ac.account_type
left join smile03.account_status ast on ast.account_status::text = ac.account_status
left join smile03.account_disposition di on di.account_disposition = ac.account_disposition
left join smile03.account_terms te on te.account_terms = ac.account_terms
left join smile03.account_contact ct on ct.account = c.account and ct.contact_type = 0
left join smile03.account_address a0 on a0.account = c.account and a0.address_type = 0
left join smile03.account_address a1 on a1.account = c.account and a1.address_type = 1
left join selfcare sc on sc.account = c.account
left join paiement p on p.account = c.account
left join nb on nb.account = c.account
left join perso pe on pe.account = c.account
order by 1;

\o
