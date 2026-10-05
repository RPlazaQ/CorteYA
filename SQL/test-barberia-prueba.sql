-- Barbería de prueba para testear el flujo de sesión de un barbero nuevo.
-- No toca los datos de "Barbería Clásica" (la demo real). Se puede borrar
-- después corriendo el DELETE del final (el cascade se lleva barberos/servicios).

insert into barbershops (id, owner_id, name, slug, address, phone, rating, timezone)
values (
  '99999999-9999-4999-8999-999999999991',
  '89155280-340e-4907-8519-d6c7a273f0d8',
  'Barbería de Prueba',
  'barberia-prueba',
  'Calle de Prueba 123',
  '+56 9 1111 1111',
  5.0,
  'America/Santiago'
);

insert into barbers (id, barbershop_id, name, specialty, active) values
  ('99999999-9999-4999-8999-999999999992', '99999999-9999-4999-8999-999999999991', 'Barbero Prueba', 'Corte y barba', true);

insert into services (id, barbershop_id, name, duration_minutes, price_clp, active) values
  ('99999999-9999-4999-8999-999999999993', '99999999-9999-4999-8999-999999999991', 'Corte de prueba', 30, 5000, true);

insert into barber_working_hours (barber_id, weekday, start_time, end_time)
select '99999999-9999-4999-8999-999999999992', w.weekday, '10:00', '20:00'
from (select generate_series(1,6) as weekday) w;

-- Para limpiar después de la prueba (el cascade borra barbers/services/working_hours):
-- delete from barbershops where id = '99999999-9999-4999-8999-999999999991';
