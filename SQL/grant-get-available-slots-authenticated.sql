-- El panel del dueño/barbero (rol authenticated) necesita llamar a
-- get_available_slots para que "+ Nueva cita" ofrezca exactamente las
-- mismas horas que ve el cliente, en vez de un campo de hora libre.
-- Hasta ahora solo estaba permitido para anon (la app pública del cliente).
--
-- Cómo probar antes de producción:
--   1. Corre este archivo.
--   2. Desde el SQL editor de Supabase, como el rol authenticated (o
--      simplemente probando desde el panel logueado como dueño):
--      select * from get_available_slots('<barber_id real>', current_date, 30);
--      → antes de este grant da "permission denied for function
--      get_available_slots"; después, debe devolver filas (o vacío si ese
--      barbero no tiene horario ese día) sin error de permisos.
--   3. Confirma que la app del cliente (anon) sigue funcionando igual —
--      este grant es aditivo, no le quita nada a anon.
--
-- Reversible:
--   revoke execute on function get_available_slots from authenticated;

grant execute on function get_available_slots to authenticated;
