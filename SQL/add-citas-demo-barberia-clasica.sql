-- Un par de citas de hoy para Barbería Clásica, con nombres reales (no
-- "Prueba CorteYa"), para que el dashboard no se vea vacío al tomar
-- capturas de pantalla para el video de Zeely.
--
-- A diferencia de test-booking-tommys.sql, estas NO son para probar el
-- bot de WhatsApp (Barbería Clásica no tiene notificación configurada),
-- son solo para que "Resumen del día" y "Calendario" tengan contenido.

insert into bookings (
  barbershop_id, barber_id, service_id,
  customer_name, customer_phone,
  booking_date, start_time, end_time,
  status, notes
) values
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  '22222222-2222-4222-8222-222222222221', -- Tomás
  '33333333-3333-4333-8333-333333333332', -- Corte + Barba, 45 min
  'Matías Fuentes',
  '+56 9 8123 4567',
  '2026-09-25',
  '15:00',
  '15:45',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  '22222222-2222-4222-8222-222222222222', -- Nico
  '33333333-3333-4333-8333-333333333331', -- Corte clásico, 30 min
  'Diego Ramírez',
  '+56 9 7456 1234',
  '2026-09-25',
  '16:30',
  '17:00',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  '22222222-2222-4222-8222-222222222221', -- Tomás
  '33333333-3333-4333-8333-333333333331', -- Corte clásico, 30 min
  'Benjamín Torres',
  '+56 9 6234 5678',
  '2026-09-25',
  '11:00',
  '11:30',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  '22222222-2222-4222-8222-222222222223', -- Caro
  '33333333-3333-4333-8333-333333333333', -- Afeitado clásico, 20 min
  'Javiera Soto',
  '+56 9 5678 1234',
  '2026-09-25',
  '11:30',
  '11:50',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  'c89dd351-370d-4806-85ed-b7e9414b2257', -- Rodri
  '6dc3b267-b04b-4db4-a677-bb32c2e91d4a', -- Corte + Tintura, 60 min
  'Camila Herrera',
  '+56 9 4321 8765',
  '2026-09-25',
  '12:00',
  '13:00',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  '22222222-2222-4222-8222-222222222222', -- Nico
  '33333333-3333-4333-8333-333333333331', -- Corte clásico, 30 min
  'Ignacio Vega',
  '+56 9 3456 7890',
  '2026-09-25',
  '13:00',
  '13:30',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  'fc5d3ac4-3caa-46cf-9a88-a601afd7d6f1', -- Pedro
  '33333333-3333-4333-8333-333333333331', -- Corte clásico, 30 min
  'Sofía Muñoz',
  '+56 9 2345 6789',
  '2026-09-25',
  '14:00',
  '14:30',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  'fc5d3ac4-3caa-46cf-9a88-a601afd7d6f1', -- Pedro
  '33333333-3333-4333-8333-333333333332', -- Corte + Barba, 45 min
  'Martín Rojas',
  '+56 9 1987 6543',
  '2026-09-25',
  '17:00',
  '17:45',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
),
(
  '11111111-1111-4111-8111-111111111111', -- Barbería Clásica
  'c89dd351-370d-4806-85ed-b7e9414b2257', -- Rodri
  '33333333-3333-4333-8333-333333333331', -- Corte clásico, 30 min
  'Valentina Castro',
  '+56 9 8765 4321',
  '2026-09-25',
  '18:30',
  '19:00',
  'confirmed',
  'DEMO SCREENSHOTS ZEELY - borrar cuando ya no se necesiten (2026-09-25)'
)
returning id, customer_name, start_time;

-- Para borrarlas cuando ya no las necesites para las capturas:
-- delete from bookings where notes like 'DEMO SCREENSHOTS ZEELY%';
