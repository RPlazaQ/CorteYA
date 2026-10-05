-- CorteYa — datos de ejemplo para seguir construyendo (Barbería Clásica)
-- Pegar en Supabase: SQL Editor -> New query -> Run
-- (Se puede correr de nuevo sin problema: primero borra cualquier dato previo de esta barbería)

delete from barbershops where slug = 'barberia-clasica';

insert into barbershops (id, owner_id, name, slug, address, phone, rating, timezone)
values (
  '11111111-1111-4111-8111-111111111111',
  'fc3688ad-1604-4dfc-ba57-6c827cd6f9cb',
  'Barbería Clásica',
  'barberia-clasica',
  'Av. Providencia 1234',
  '+56 9 0000 0000',
  4.8,
  'America/Santiago'
);

insert into barbers (id, barbershop_id, name, specialty, active) values
  ('22222222-2222-4222-8222-222222222221', '11111111-1111-4111-8111-111111111111', 'Tomás', 'Corte y barba', true),
  ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111', 'Nico',  'Especialista en fade', true),
  ('22222222-2222-4222-8222-222222222223', '11111111-1111-4111-8111-111111111111', 'Caro',  'Corte clásico', true);

insert into services (id, barbershop_id, name, duration_minutes, price_clp, active) values
  ('33333333-3333-4333-8333-333333333331', '11111111-1111-4111-8111-111111111111', 'Corte clásico',    30, 8000,  true),
  ('33333333-3333-4333-8333-333333333332', '11111111-1111-4111-8111-111111111111', 'Corte + Barba',    45, 12000, true),
  ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 'Afeitado clásico', 20, 6000,  true);

-- Horario: lunes(1) a sábado(6), 10:00 a 20:00. Domingo(0) cerrado (sin fila = cerrado).
insert into barber_working_hours (barber_id, weekday, start_time, end_time)
select b.id, w.weekday, '10:00', '20:00'
from barbers b
cross join (select generate_series(1,6) as weekday) w
where b.barbershop_id = '11111111-1111-4111-8111-111111111111';
