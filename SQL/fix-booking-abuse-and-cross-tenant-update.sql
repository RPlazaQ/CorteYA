-- Fase 2 de la auditoría de seguridad (2026-11-02). Dos huecos separados,
-- agrupados en un solo archivo porque los dos son triggers sobre bookings:
--
-- 1. (Alto) "guest can create a booking" no tenía ningún límite de
--    velocidad (a diferencia de reviews, que ya tiene limit_review_rate).
--    Cualquiera podía llenar la agenda completa de un barbero por 29 días,
--    o spamear el WhatsApp del dueño (cada insert dispara un mensaje real).
--
-- 2. (Alto) validate_booking_consistency() (la función que revisa que
--    barber_id/service_id pertenezcan a barbershop_id, y que end_time
--    calce con la duración del servicio) solo corría en INSERT. La policy
--    de UPDATE de bookings solo exige que barbershop_id sea tuyo — no
--    revisa que barber_id/service_id sigan perteneciendo a esa barbería.
--    Un dueño podía hacer UPDATE a una reserva propia y apuntar barber_id
--    a un barbero de OTRA barbería (ej. para bloquearle un horario a un
--    competidor), sin pasar por ninguna de las validaciones que si tiene
--    el INSERT.
--
-- Nada de esto cambia el comportamiento normal de la app: revisé todos los
-- UPDATE que hace dashboard-barberia.html sobre bookings (cambiar status:
-- Llegó, No llegó, cancelar, etc.) y ninguno toca barber_id/service_id/
-- end_time — siguen siendo los mismos valores que ya pasaron la validación
-- al crear la reserva, así que el trigger extendido los deja pasar igual.
--
-- Cómo probar:
--   1. Corre este archivo completo.
--   2. Reservas normales (desde la app o un insert válido) siguen
--      funcionando igual.
--   3. Intenta insertar 4 reservas seguidas con el mismo customer_phone en
--      menos de 10 minutos -> la 4ta debe fallar con el mensaje de límite.
--   4. Con una cuenta de dueño, intenta:
--        update bookings set barber_id = '<barbero de OTRA barbería>'
--        where id = '<una reserva propia>';
--      -> debe fallar con "El barbero no pertenece a esta barbería".
--   5. Cambiar solo el status de una reserva propia (como ya hace la app)
--      sigue funcionando sin error.
--
-- Reversible:
--   drop trigger if exists trg_limit_booking_rate on bookings;
--   drop function if exists limit_booking_rate();
--   drop trigger if exists trg_validate_booking_consistency on bookings;
--   create trigger trg_validate_booking_consistency
--     before insert on bookings
--     for each row execute function validate_booking_consistency();

-- 1. límite de velocidad: máximo 3 reservas por teléfono, o 20 por
--    barbería, cada 10 minutos. El límite por teléfono no aplica si viene
--    sin teléfono (reserva manual del dueño sin dato del cliente) — para
--    ese caso igual corre el límite por barbería, que no debería afectar
--    el uso real de ningún local del piloto.
create or replace function limit_booking_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count_phone int;
  recent_count_shop int;
begin
  if new.customer_phone is not null then
    select count(*) into recent_count_phone
    from bookings
    where customer_phone = new.customer_phone
      and created_at > now() - interval '10 minutes';

    if recent_count_phone >= 3 then
      raise exception 'Ya tienes varias reservas recientes, espera unos minutos antes de crear otra';
    end if;
  end if;

  select count(*) into recent_count_shop
  from bookings
  where barbershop_id = new.barbershop_id
    and created_at > now() - interval '10 minutes';

  if recent_count_shop >= 20 then
    raise exception 'Se alcanzó el límite de reservas nuevas por el momento, intenta en unos minutos';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_limit_booking_rate on bookings;
create trigger trg_limit_booking_rate
  before insert on bookings
  for each row execute function limit_booking_rate();

-- 2. la consistencia de barber_id/service_id/end_time ahora también se
--    revisa en UPDATE, no solo en INSERT (misma función, sin cambios).
drop trigger if exists trg_validate_booking_consistency on bookings;
create trigger trg_validate_booking_consistency
  before insert or update on bookings
  for each row execute function validate_booking_consistency();
