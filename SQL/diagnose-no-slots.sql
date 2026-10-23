-- Los horarios base están bien (lunes a viernes 10-20), así que el
-- problema no es que falten filas en barber_working_hours. Esto prueba la
-- función get_available_slots() directo, sin pasar por la app, para ver
-- si el problema está en la base de datos o en la página.

-- 1) llama a la función tal cual la llama la app, para un barbero real de
--    Barbería Clásica y mañana (ajusta el nombre si quieres probar otro)
select *
from get_available_slots(
  (select id from barbers where barbershop_id = (select id from barbershops where slug = 'barberia-clasica') and active limit 1),
  (current_date + 1),
  30
);
-- si esto devuelve filas con horas -> el problema está en la página
-- (app-cliente.html), no en la base de datos.
-- si esto NO devuelve nada -> seguimos bajando con las consultas de abajo.

-- 2) ¿hay algún día libre (vacaciones/feriado) que esté tapando todas las
--    fechas sin querer? (ej: un rango con la fecha "hasta" mal puesta)
select b.name, t.start_date, t.end_date
from barber_time_off t
join barbers b on b.id = t.barber_id
where b.barbershop_id = (select id from barbershops where slug = 'barberia-clasica');

-- 3) ¿el fin de semana también debería tener horario? Los datos que
--    revisamos solo mostraron lunes a viernes (weekday 1-5) — si estás
--    probando sábado o domingo en la app, por eso no hay horas ese día.
-- weekday: 0=domingo, 1=lunes, 2=martes, 3=miércoles, 4=jueves, 5=viernes, 6=sábado
select extract(dow from current_date) as hoy_weekday, extract(dow from current_date + 1) as mañana_weekday;
