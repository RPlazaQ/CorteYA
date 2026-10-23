-- Hoy es viernes (weekday 5), así que "mañana" caía sábado (weekday 6) —
-- por eso el diagnóstico anterior no devolvió horas: ese barbero no tiene
-- horario configurado los sábados, no es un bug. Esto prueba lo mismo
-- pero para el próximo lunes, que sí debería tener horario (10-20).

select *
from get_available_slots(
  (select id from barbers where barbershop_id = (select id from barbershops where slug = 'barberia-clasica') and active limit 1),
  (current_date + 3), -- próximo lunes
  30
);
