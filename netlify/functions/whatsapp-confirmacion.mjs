// Llamada por el trigger de Postgres (trg_whatsapp_confirmacion) justo
// después de crear una reserva. No lee Supabase: todo el payload viene
// ya armado desde el trigger.

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
      templateName: 'confirmacion_reserva',
      params: [customer_name, barbershop_name, service_name, formatFecha(booking_date), formatHora(start_time), barber_name],
    });
    return new Response('ok', { status: 200 });
  } catch (e) {
    console.error('whatsapp-confirmacion error', e);
    return new Response('error', { status: 500 });
  }
};
