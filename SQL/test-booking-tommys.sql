-- Reserva de prueba para Tommy's Barber Shop — verificar que llegue el
-- WhatsApp de aviso de nueva reserva al dueño (nueva_reserva_barbero).
-- El teléfono de la barbería ya está puesto al número de Rodrigo
-- (+56985015663) para esta prueba.
--
-- Correr en el SQL Editor de Supabase (bypassa RLS al correr como
-- postgres, por eso no se puede insertar por la REST API con la anon key).

insert into bookings (
  barbershop_id, barber_id, service_id,
  customer_name, customer_phone,
  booking_date, start_time, end_time,
  status, notes
) values (
  '33c0cc9a-a9f0-4e56-aed7-50b6f343f2c9', -- Tommy's Barber Shop
  '73fef9db-bf3f-4df4-b517-113320aea145', -- tomas
  '119f7e86-cdd9-453c-bdb2-b2baf999d95e', -- corte clasico, 30 min
  'Prueba CorteYa',
  '+56 9 1234 5678',
  '2026-09-24',
  '10:00',
  '10:30',
  'confirmed',
  'RESERVA DE PRUEBA - cancelar tras confirmar que llego el WhatsApp (2026-09-23)'
)
returning id;

-- Para cancelar/borrar después de confirmar que llegó el WhatsApp:
-- delete from bookings where notes like 'RESERVA DE PRUEBA%';
