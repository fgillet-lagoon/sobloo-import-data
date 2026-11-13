-- Inclus deux fois par export_catalogue.sql : :reduction_one_shot = false (4_articles) ou true (5b_reductions_one_shot).
-- Invoice items actifs (itemdescription de type 6). Prix négatif = réduction ponctuelle (Lagoon, 13/11/2026).
with taux as (
    select distinct on (tax_treatment) tax_treatment, percentage_rate
    from smile03.tax_schedule_item where tax_schedule = 1 and start_date <= current_date
    order by tax_treatment, start_date desc
)
select i.itemcode as "code Smile", i.name as "désignation", i.rate as "prix HT", i.currency as "devise",
       i.validfrom as "valide du", i.validto as "valide au",
       t.glcode as "compte de vente", t.name as "libellé compte", i.txcode as "code compte Smile",
       tt.name as "taxe", tx.percentage_rate as "taux taxe %"
from public.itemdescription i
left join public.txdescription t on t.txcode = i.txcode and t.company = i.company
left join smile03.tax_treatment tt on tt.tax_treatment = i.taxtreatment
left join taux tx on tx.tax_treatment = i.taxtreatment
where i.chargetype = 6
  and (i.validto is null or i.validto >= current_date)
  and (i.itemcode || ' ' || coalesce(i.name, '') || ' ' || coalesce(t.glcode, '') || ' ' || coalesce(t.name, '')) !~* :'exclusion_texte'
  and (coalesce(i.rate, 0) < 0) = :reduction_one_shot
order by t.glcode, i.itemcode;
