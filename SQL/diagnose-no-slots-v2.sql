-- Mi error: usé current_date en los diagnósticos anteriores, que es la
-- fecha del servidor (normalmente UTC), no la de Chile — por eso decía
-- "viernes" cuando en Chile todavía era jueves. La app sí calcula bien la
-- fecha en hora de Chile (santiagoDateParts() en app-cliente.html usa
-- Intl con timeZone: 'America/Santiago'), pero este diagnóstico tiene que
-- usar lo mismo para no confundirnos de nuevo.

-- confirma qué día es "hoy" y "mañana" en hora de Chile
select
  (now() at time zone 'America/Santiago')::date as hoy_chile,
  extract(dow from (now() at time zone 'America/Santiago')::date) as hoy_weekday,
  ((now() at time zone 'America/Santiago')::date + 1) as mañana_chile,
  extract(dow from (now() at time zone 'America/Santiago')::date + 1) as mañana_weekday;

-- llama a la función para MAÑANA en hora de Chile (debería ser viernes,
-- que sí tiene horario 10-20 según lo que ya revisamos)
select *
from get_available_slots(
  (select id from barbers where barbershop_id = (select id from barbershops where slug = 'barberia-clasica') and active limit 1),
  ((now() at time zone 'America/Santiago')::date + 1),
  30
);
