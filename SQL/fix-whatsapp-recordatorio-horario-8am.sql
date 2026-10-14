-- Cambia el recordatorio al cliente ('recordatorio_cita_cliente_v2') de
-- "2-3 horas antes de la cita" a "8:00 AM del mismo día de la cita".
--
-- Por qué el cambio: la confirmación inmediata al agendar ahora la cubre
-- 'confirmacion_cita_dia_v1' (ver add-whatsapp-confirmacion-cliente.sql),
-- así que este mensaje pasa a ser el recordatorio de la mañana, no uno
-- justo antes de la hora.
--
-- Mismo mecanismo que antes (cron.schedule cada 15 min ya existente,
-- columna reminder_sent_at ya existente evita reenvíos) — solo cambia
-- la condición de la ventana en el WHERE.

create or replace function send_whatsapp_reminders() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  r record;
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
begin
  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    return;
  end if;

  for r in
    select bk.id, bk.customer_name, bk.customer_phone, bk.booking_date, bk.start_time,
           s.name as barbershop_name, b.name as barber_name, sv.name as service_name
    from bookings bk
    join barbershops s on s.id = bk.barbershop_id
    join barbers b on b.id = bk.barber_id
    join services sv on sv.id = bk.service_id
    where bk.status = 'confirmed'
      and bk.reminder_sent_at is null
      and bk.customer_phone is not null
      and bk.booking_date = (now() at time zone 'America/Santiago')::date
      and extract(hour from now() at time zone 'America/Santiago') = 8
  loop
    v_to_digits := regexp_replace(r.customer_phone, '[^0-9]', '', 'g');

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
          'name', 'recordatorio_cita_cliente_v2',
          'language', jsonb_build_object('code', 'es'),
          'components', jsonb_build_array(
            jsonb_build_object(
              'type', 'body',
              'parameters', jsonb_build_array(
                jsonb_build_object('type', 'text', 'text', r.customer_name),
                jsonb_build_object('type', 'text', 'text', r.barbershop_name),
                jsonb_build_object('type', 'text', 'text', r.service_name),
                jsonb_build_object('type', 'text', 'text', r.barber_name),
                jsonb_build_object('type', 'text', 'text', to_char(r.booking_date, 'DD/MM/YYYY')),
                jsonb_build_object('type', 'text', 'text', to_char(r.start_time, 'HH24:MI'))
              )
            )
          )
        )
      )
    );

    update bookings set reminder_sent_at = now() where id = r.id;
  end loop;
end;
$$;

-- El cron job 'whatsapp-recordatorio-cliente' ya existe (cada 15 min) y
-- sigue llamando a esta misma función — no hace falta tocarlo.
