-- Aviso por WhatsApp al CLIENTE apenas termina de agendar en la app
-- (inmediato, mismo momento en que se avisa al barbero via
-- trg_whatsapp_nueva_reserva). Usa la plantilla 'confirmacion_cita_dia_v1'.
--
-- Distinto de 'recordatorio_cita_cliente_v2' (ver
-- fix-whatsapp-recordatorio-horario-8am.sql), que ahora se manda la
-- mañana del día de la cita, no al momento de agendar.

alter table bookings add column if not exists client_confirmed_at timestamptz;

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
  if new.status <> 'confirmed' or new.customer_phone is null then
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

drop trigger if exists trg_whatsapp_confirmacion_cliente on bookings;
create trigger trg_whatsapp_confirmacion_cliente
after insert on bookings
for each row execute function notify_whatsapp_confirmacion_cliente();
