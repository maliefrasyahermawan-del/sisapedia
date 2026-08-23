insert into public.formula_versions(version,points_per_kg,emissions_factor,economic_factor,active)
values ('semarang-2026-v1',10,1.4,1,true)
on conflict(version) do update set points_per_kg=excluded.points_per_kg,
  emissions_factor=excluded.emissions_factor,economic_factor=excluded.economic_factor,active=true;
insert into public.baselines(city_id,month,target_kg,formula_version_id)
select c.id,months.month,10000,f.id
from public.cities c cross join public.formula_versions f
cross join generate_series(date '2026-01-01',date '2026-12-01',interval '1 month') months(month)
where c.code='semarang' and f.version='semarang-2026-v1'
on conflict(city_id,month) do update set target_kg=excluded.target_kg,formula_version_id=excluded.formula_version_id;
