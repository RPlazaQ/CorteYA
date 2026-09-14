// Llamada por el trigger de Postgres (trg_whatsapp_nueva_reserva) justo
// después de crear una reserva. Avisa al BARBERO, no al cliente — ver
// add-whatsapp-nueva-reserva.sql para el porqué. No lee Supabase: todo el
// payload viene ya armado desde el trigger.

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

  const { barbershop_phone, barber_name, service_name, customer_name, customer_phone, booking_date, start_time } = payload;

  if (!barbershop_phone) {
    return new Response('Missing barbershop_phone', { status: 400 });
  }

  try {
    await sendWhatsAppTemplate({
      to: barbershop_phone,
      templateName: 'nueva_reserva_barbero',
      params: [service_name, formatFecha(booking_date), formatHora(start_time), barber_name, customer_name, customer_phone],
    });
    return new Response('ok', { status: 200 });
  } catch (e) {
    console.error('whatsapp-nueva-reserva error', e);
    return new Response('error', { status: 500 });
  }
};
