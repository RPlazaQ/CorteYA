// Webhook receptor de Meta para el producto WhatsApp de la app CorteYa.
//
// Este endpoint es requerido por Meta como parte de "Configuración de
// producción" del producto WhatsApp (paso necesario para sacar la app de
// dev_mode). Por ahora solo:
//   - GET:  responde el handshake de verificación de Meta (hub.challenge).
//   - POST: acepta y loguea los eventos entrantes (mensajes, estados de
//           entrega) con un 200 OK. Todavía no hacemos nada con ellos —
//           el bot actual (whatsapp-nueva-reserva.mjs) solo envía, no
//           recibe. Si más adelante se necesita reaccionar a respuestas
//           de clientes o a estados de entrega, la lógica va acá.

export default async (request) => {
  const url = new URL(request.url);

  if (request.method === 'GET') {
    const mode = url.searchParams.get('hub.mode');
    const token = url.searchParams.get('hub.verify_token');
    const challenge = url.searchParams.get('hub.challenge');

    const expected = process.env.WHATSAPP_VERIFY_TOKEN;
    if (mode === 'subscribe' && expected && token === expected) {
      return new Response(challenge, { status: 200 });
    }
    return new Response('Forbidden', { status: 403 });
  }

  if (request.method === 'POST') {
    let body;
    try {
      body = await request.json();
    } catch {
      return new Response('Bad request', { status: 400 });
    }
    console.log('whatsapp-webhook event', JSON.stringify(body));
    return new Response('EVENT_RECEIVED', { status: 200 });
  }

  return new Response('Method not allowed', { status: 405 });
};
