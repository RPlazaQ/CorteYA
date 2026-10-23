-- Diagnóstico: por qué no aparecen horarios disponibles en ningún día.
--
-- No es por la función de foto/descripción del barbero
-- (update_barber_profile, en add-barber-profile.sql) — esa función SOLO
-- actualiza barbers.photo_url y barbers.bio, no toca para nada
-- barber_working_hours. get_available_slots() depende 100% de que existan
-- filas en barber_working_hours para el barbero y el día de la semana
-- (weekday: 0=domingo .. 6=sábado) — si no hay fila para ese weekday, no
-- hay horas, sin importar qué tan bien esté configurado todo lo demás.

-- 1) revisa qué tiene cada barbero de Barbería Clásica ahora mismo
select b.name, w.weekday, w.start_time, w.end_time
from barbers b
left join barber_working_hours w on w.barber_id = b.id
where b.barbershop_id = (select id from barbershops where slug = 'barberia-clasica')
order by b.name, w.weekday;

-- 2) si el select de arriba te muestra barberos con weekday/start_time/
--    end_time en NULL (sin ninguna fila), este insert les deja un horario
--    por defecto de lunes a sábado 10:00-20:00 — SOLO a los que no tengan
--    ninguna fila todavía (no toca a nadie que ya tenga su horario
--    configurado, aunque sea distinto al default).
insert into barber_working_hours (barber_id, weekday, start_time, end_time)
select b.id, weekday, '10:00', '20:00'
from barbers b
cross join generate_series(1, 6) as weekday
where b.barbershop_id = (select id from barbershops where slug = 'barberia-clasica')
  and not exists (select 1 from barber_working_hours w where w.barber_id = b.id);
