-- Cambia el trigger de aviso al barbero para llamar a la API de Meta
-- DIRECTO desde Postgres (via pg_net), en vez de pasar por la Netlify
-- Function/Edge Function.
--
-- Por qué: tras una sesión larga de debugging (2026-09-23), confirmamos
-- que exactamente la misma llamada (mismo token, mismo phone_number_id,
-- misma plantilla) funciona perfecto llamada directo (curl, fetch de
-- Node) desde fuera de Netlify, pero SIEMPRE falla con el mismo error
-- ("Object does not exist / missing permissions", code 100 subcode 33)
-- cuando corre dentro de una Netlify Function o Edge Function. Todo
-- apunta a que Meta trata distinto el tráfico saliente desde la
-- infraestructura de Netlify. Saltarse ese hop evita el problema.
--
-- IMPORTANTE: antes de correr este archivo, corre por separado (te lo paso
-- por chat, fuera de git) los inserts con los secretos reales:
--   insert into app_secrets (key, value) values ('whatsapp_token', '<token>')
--   on conflict (key) do update set value = excluded.value;
--   insert into app_secrets (key, value) values ('whatsapp_phone_number_id', '<id>')
--   on conflict (key) do update set value = excluded.value;

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
              jsonb_build_object('type', 'text', 'text', new.customer_phone)
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
