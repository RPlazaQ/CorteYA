-- Ajusta los triggers de WhatsApp para que una reserva sin teléfono
-- (ver allow-null-customer-phone.sql) nunca rompa el envío al dueño ni
-- quede en silencio sin dejar rastro.
--
-- Qué cambia en cada uno:
--
-- 1) notify_whatsapp_nueva_reserva (aviso AL DUEÑO cuando entra una cita):
--    el teléfono del cliente es uno de los parámetros de la plantilla. Si
--    va NULL, jsonb_build_object metía "text": null en el body y la llamada
--    a la API de Meta completa fallaba (el mensaje entero no se mandaba,
--    ni con los demás datos). Ahora se reemplaza por 'Sin teléfono' solo
--    para ese parámetro — el aviso al dueño se sigue mandando igual.
--
-- 2) notify_whatsapp_confirmacion_cliente (confirmación AL CLIENTE): ya
--    cortaba temprano si customer_phone is null (no hay a quién mandarle
--    nada, correcto). Lo único que faltaba es dejarlo registrado en vez de
--    salir en silencio — se agrega un `raise log` visible en los logs de
--    Postgres de Supabase.
--
-- El recordatorio de la mañana (send_whatsapp_reminders, ver
-- fix-whatsapp-recordatorio-horario-8am.sql) NO se toca: ya filtra
-- `customer_phone is not null` en el WHERE, así que una cita sin teléfono
-- simplemente no entra al loop — no hace falta ningún cambio ahí.
--
-- Cómo probar antes de producción:
--   1. Corre este archivo junto con allow-null-customer-phone.sql.
--   2. Inserta una reserva de prueba con customer_phone = null.
--   3. Revisa Logs → Postgres Logs en el dashboard de Supabase: debe
--      aparecer la línea "Confirmación WhatsApp omitida (sin teléfono)...".
--   4. Si tienes los secretos de WhatsApp cargados en app_secrets, revisa
--      que SÍ llegó el mensaje al dueño (notify_whatsapp_nueva_reserva no
--      se salta por el teléfono nulo) y que diga "Sin teléfono" donde iría
--      el número del cliente.
--   5. Repite con un teléfono real y confirma que todo sigue como antes
--      (sin "Sin teléfono", con el número real).
--
-- Reversible: para volver a la versión anterior de cada función, re-corre
-- fix-whatsapp-direct-meta.sql (para notify_whatsapp_nueva_reserva) y
-- add-whatsapp-confirmacion-cliente.sql (para notify_whatsapp_confirmacion_cliente).

create or replace function notify_whatsapp_nueva_reserva() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_barbershop_phone text;
  v_barber_name text;
  v_service_name text;
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  select s.phone, b.name, sv.name
  into v_barbershop_phone, v_barber_name, v_service_name
  from barbershops s, barbers b, services sv
  where s.id = new.barbershop_id and b.id = new.barber_id and sv.id = new.service_id;

  if v_barbershop_phone is null then
    return new;
  end if;

  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    return new;
  end if;

  v_to_digits := regexp_replace(v_barbershop_phone, '[^0-9]', '', 'g');

  perform net.http_post(
    url := 'https://graph.facebook.com/v26.0/' || v_phone_number_id || '/messages',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_token
    ),
    body := jsonb_build_object(
      'messaging_product', 'whatsapp',
      'to', v_to_digits,
      'type', 'template',
      'template', jsonb_build_object(
        'name', 'nueva_reserva_barbero',
        'language', jsonb_build_object('code', 'es'),
        'components', jsonb_build_array(
          jsonb_build_object(
            'type', 'body',
            'parameters', jsonb_build_array(
              jsonb_build_object('type', 'text', 'text', v_service_name),
              jsonb_build_object('type', 'text', 'text', to_char(new.booking_date, 'DD/MM/YYYY')),
              jsonb_build_object('type', 'text', 'text', to_char(new.start_time, 'HH24:MI')),
              jsonb_build_object('type', 'text', 'text', v_barber_name),
              jsonb_build_object('type', 'text', 'text', new.customer_name),
              jsonb_build_object('type', 'text', 'text', coalesce(new.customer_phone, 'Sin teléfono'))
            )
          )
        )
      )
    )
  );

  update bookings set owner_notified_at = now() where id = new.id;
  return new;
end;
$$;

create or replace function notify_whatsapp_confirmacion_cliente() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_barbershop_name text;
  v_barber_name text;
  v_service_name text;
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  if new.customer_phone is null then
    raise log 'Confirmación WhatsApp omitida (sin teléfono): booking %', new.id;
    return new;
  end if;

  select s.name, b.name, sv.name
  into v_barbershop_name, v_barber_name, v_service_name
  from barbershops s, barbers b, services sv
  where s.id = new.barbershop_id and b.id = new.barber_id and sv.id = new.service_id;

  if v_barbershop_name is null then
    return new;
  end if;

  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    return new;
  end if;

  v_to_digits := regexp_replace(new.customer_phone, '[^0-9]', '', 'g');

  perform net.http_post(
    url := 'https://graph.facebook.com/v26.0/' || v_phone_number_id || '/messages',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_token
    ),
    body := jsonb_build_object(
      'messaging_product', 'whatsapp',
      'to', v_to_digits,
      'type', 'template',
      'template', jsonb_build_object(
        'name', 'confirmacion_cita_dia_v1',
        'language', jsonb_build_object('code', 'es'),
        'components', jsonb_build_array(
          jsonb_build_object(
            'type', 'body',
            'parameters', jsonb_build_array(
              jsonb_build_object('type', 'text', 'text', new.customer_name),
              jsonb_build_object('type', 'text', 'text', v_barbershop_name),
              jsonb_build_object('type', 'text', 'text', v_service_name),
              jsonb_build_object('type', 'text', 'text', v_barber_name),
              jsonb_build_object('type', 'text', 'text', to_char(new.booking_date, 'DD/MM/YYYY')),
              jsonb_build_object('type', 'text', 'text', to_char(new.start_time, 'HH24:MI'))
            )
          )
        )
      )
    )
  );

  update bookings set client_confirmed_at = now() where id = new.id;
  return new;
end;
$$;
