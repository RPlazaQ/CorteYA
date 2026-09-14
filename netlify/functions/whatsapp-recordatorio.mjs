// Llamada por pg_cron (send_whatsapp_recordatorios), cada 15 minutos, por
// cada reserva que empieza entre 60 y 75 minutos desde ahora. No lee
// Supabase: todo el payload viene ya armado desde la función de Postgres.

import { checkSecret, sendWhatsAppTemplate, formatFecha, formatHora } from './_whatsapp.mjs';

export default async (request) => {
  if (!checkSecret(request)) {
    return new Response('Unauthorized', { status: 401 });
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response('Bad request', { status: 400 });
  }

  const { customer_name, customer_phone, barbershop_name, barber_name, service_name, booking_date, start_time } = payload;

  if (!customer_phone) {
    return new Response('Missing customer_phone', { status: 400 });
  }

  try {
    await sendWhatsAppTemplate({
      to: customer_phone,
      templateName: 'recordatorio_reserva',
      params: [customer_name, barbershop_name, service_name, formatFecha(booking_date), formatHora(start_time), barber_name],
    });
    return new Response('ok', { status: 200 });
  } catch (e) {
    console.error('whatsapp-recordatorio error', e);
    return new Response('error', { status: 500 });
  }
};
