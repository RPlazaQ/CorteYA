// Helper compartido: manda un mensaje de plantilla ya aprobada por Meta.
// No lee la base de datos — recibe los datos ya armados desde quien lo llama.
//
// MOVIDO A EDGE FUNCTION (2026-09-23): como Netlify Function normal (AWS
// Lambda, netlify/functions/) las llamadas salientes a graph.facebook.com
// siempre volvían con "Object with ID ... does not exist, cannot be
// loaded due to missing permissions" (code 100, subcode 33) -- con el
// mismo token/ID/plantilla que sí funcionaban perfecto llamados a mano
// (curl desde otra máquina, botón de prueba de Meta). El patrón apuntaba
// a que Meta bloquea/trata distinto el rango de IPs de salida de AWS
// Lambda que usa Netlify Functions. Las Edge Functions corren en la red
// edge de Netlify, con IPs de salida distintas -- de ahí el cambio.
//
// Nota Deno: las Edge Functions corren en Deno, no Node -- `process.env`
// no existe acá, hay que usar `Netlify.env.get()`.

const GRAPH_VERSION = 'v26.0';

export function checkSecret(request) {
  const expected = (Netlify.env.get('WHATSAPP_WEBHOOK_SECRET') || '').trim();
  const got = request.headers.get('x-corteya-secret');
  return Boolean(expected) && got === expected;
}

export function formatFecha(dateStr) {
  const [y, m, d] = String(dateStr).split('-');
  return `${d}/${m}/${y}`;
}

export function formatHora(timeStr) {
  return String(timeStr).slice(0, 5);
}

export async function sendWhatsAppTemplate({ to, templateName, languageCode = 'es', params }) {
  // .trim() por si quedó un espacio/salto de línea pegado al copiar el valor
  // en Netlify — con eso el ID "se ve" igual pero la URL apunta a un objeto
  // que Meta no reconoce, y el error que devuelve es indistinguible de un
  // ID realmente incorrecto.
  const phoneNumberId = (Netlify.env.get('WHATSAPP_PHONE_NUMBER_ID') || '').trim();
  const token = (Netlify.env.get('WHATSAPP_TOKEN') || '').trim();
  if (!phoneNumberId || !token) {
    throw new Error('Faltan WHATSAPP_PHONE_NUMBER_ID o WHATSAPP_TOKEN en las variables de entorno');
  }

  // WhatsApp espera el número en dígitos con código de país, sin "+" ni espacios
  const toDigits = String(to).replace(/[^\d]/g, '');

  const res = await fetch(`https://graph.facebook.com/${GRAPH_VERSION}/${phoneNumberId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to: toDigits,
      type: 'template',
      template: {
        name: templateName,
        language: { code: languageCode },
        components: [
          {
            type: 'body',
            parameters: params.map((text) => ({ type: 'text', text: String(text) })),
          },
        ],
      },
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`WhatsApp API error ${res.status}: ${JSON.stringify(data)}`);
  }
  return data;
}
