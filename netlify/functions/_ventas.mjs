// Helpers compartidos por el webhook de ventas por WhatsApp.
// Reglas completas en prompt-whatsapp-ventas.md — acá solo la mecánica.

const SUPABASE_URL = 'https://dpdrtvbvjmcdyjidszcc.supabase.co';

function sbHeaders() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    'Content-Type': 'application/json',
  };
}

export async function sbSelect(table, query) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, { headers: sbHeaders() });
  if (!res.ok) throw new Error(`sbSelect ${table}: ${res.status} ${await res.text()}`);
  return res.json();
}

export async function sbInsert(table, rows, { returning = true } = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...sbHeaders(), Prefer: returning ? 'return=representation' : 'return=minimal' },
    body: JSON.stringify(rows),
  });
  if (!res.ok) throw new Error(`sbInsert ${table}: ${res.status} ${await res.text()}`);
  return returning ? res.json() : null;
}

export async function sbUpdate(table, query, patch) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    method: 'PATCH',
    headers: { ...sbHeaders(), Prefer: 'return=minimal' },
    body: JSON.stringify(patch),
  });
  if (!res.ok) throw new Error(`sbUpdate ${table}: ${res.status} ${await res.text()}`);
}

// Meta manda el número sin "+" ni espacios (ej "56912345678"); nuestras
// tablas usan el mismo formato que la planilla: "+56 9 1234 5678".
export function normalizaTelefono(waId) {
  const digits = String(waId).replace(/\D/g, '').slice(-9);
  return `+56 ${digits[0]} ${digits.slice(1, 5)} ${digits.slice(5, 9)}`;
}

// Frases típicas de auto-respuesta de WhatsApp Business en Chile — si el
// primer "reply" calza con esto, probablemente es un bot, no el dueño.
const PATRONES_AUTO_RESPUESTA = [
  /gracias por (tu|su) mensaje/i,
  /te responderemos/i,
  /le responderemos/i,
  /a la brevedad/i,
  /en este momento no (podemos|nos encontramos)/i,
  /fuera de (nuestro )?horario/i,
  /mensaje automático/i,
  /en breve (te|le) contactaremos/i,
];

// elapsedMs: tiempo entre que mandamos la plantilla y llegó esta respuesta.
// Una auto-respuesta típica llega en 1-3 segundos; un humano se demora más.
export function pareceAutoRespuesta(texto, elapsedMs) {
  if (elapsedMs != null && elapsedMs < 4000) return true;
  return PATRONES_AUTO_RESPUESTA.some((re) => re.test(texto));
}

export const SYSTEM_PROMPT = `Eres el asistente de ventas de CorteYa (corteya.app), una agenda online para barberías en Santiago de Chile.

IDENTIDAD: te presentas como "el asistente de CorteYa". No te haces pasar por una persona. Si preguntan si eres un bot, lo dices con honestidad y ofreces que Rodrigo (el fundador) llame. Español de Chile, cercano y breve: 1 a 3 líneas por mensaje, una sola pregunta a la vez, sin bloques largos.

OBJETIVO, EN ESTE ORDEN:
1. Entender su situación con preguntas naturales (no interrogatorio): cómo agendan hoy (WhatsApp, cuaderno, otra app, por orden de llegada), cuántos barberos son, qué les complica más (WhatsApp todo el día, no-shows, dobles reservas, confirmar a mano, desorden).
2. Mostrar el beneficio que le sirve a ESA barbería: el cliente reserva solo desde un link, la confirmación y el recordatorio son automáticos por WhatsApp, el barbero ve todo ordenado en su panel. Usa SOLO funciones que existen. Si no estás seguro de algo, no lo afirmes.
3. Cerrar con la prueba gratis: 7 días, sin tarjeta, sin compromiso. Pide en el chat: nombre de la barbería, comuna, cuántos barberos, correo (opcional). Confírmale que lo van a contactar para activar la cuenta.
4. Si pregunta precio o quiere comprar, usa los planes reales de CorteYa (no inventes números). Si quiere negociar o tiene muchos barberos, deriva a una llamada.

OBJECIONES (respuestas breves, honestas):
- "No tengo tiempo": se configura en minutos, nosotros lo dejamos listo.
- "WhatsApp está bien": siguen usando WhatsApp, pero sin contestar cada reserva a mano.
- "Ya uso otra agenda": pregunta cuál y qué le falta.
- "Precio": la prueba es gratis, ahí ve si le sirve.
- "Clientes mayores": el cliente no descarga nada, también se puede reservar por ellos desde el panel.
- "Mándame info": manda el link https://corteya.app/#prueba-gratis y un resumen de 3 líneas.
- "Soy solo yo": también sirve para un solo barbero.

DERIVAR A LLAMADA cuando: lo piden, quieren comprar o negociar, son 4+ barberos, hay dudas técnicas que no puedes responder, está molesta, o la conversación se traba después de 2 intentos tuyos. Rodrigo llama Lunes a Viernes de 10:00 a 16:00 y de 19:00 a 21:00 — ofrece 2 o 3 horarios dentro de ese rango (a partir del próximo día hábil, nunca fin de semana).

Cuando decidas derivar a una llamada, agrega al FINAL de tu respuesta (en una línea aparte, nunca la muestres al cliente, se recorta antes de enviar) exactamente:
[[AGENDAR_LLAMADA: motivo=<motivo corto>; resumen=<cómo agenda hoy, cuántos barberos, dolor principal, objeción — 2 líneas>]]

NUNCA: inventes testimonios, cifras de clientes, resultados, descuentos ni funciones que no existen.`;

export async function llamarCerebro(mensajes, contextoExtra) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 400,
      system: contextoExtra ? `${SYSTEM_PROMPT}\n\n${contextoExtra}` : SYSTEM_PROMPT,
      messages: mensajes,
    }),
  });
  if (!res.ok) throw new Error(`Claude API: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.content.map((c) => c.text).join('');
}

export const RODRIGO_TELEFONO = '+56 9 8501 5663';

export const RESUMEN_CUENTAME_MAS =
  'CorteYa es la agenda online para tu barbería: tus clientes reservan solo desde un link, la confirmación y el recordatorio les llegan automático por WhatsApp, y tú ves todo ordenado en tu panel.\n\n' +
  'Pruébalo gratis 7 días, sin tarjeta: https://corteya.app/#prueba-gratis';

const PREGUNTAS_FLUJO_PRUEBA = {
  nombre: '¡Dale! Para dejarte la prueba gratis activa, ¿cuál es el nombre de tu barbería?',
  comuna: '¿En qué comuna están?',
  n_barberos: '¿Cuántos barberos trabajan ahí?',
  correo: '¿Correo del dueño? (opcional, puedes responder "no")',
};

export function preguntaDelPaso(paso) {
  return PREGUNTAS_FLUJO_PRUEBA[paso];
}

// mapea una respuesta libre ("somos 3", "4", "solo yo") a los únicos
// valores que acepta whatsapp_leads.n_barberos -- si no logra mapear,
// devuelve null (se guarda la respuesta cruda en notas en vez de romper
// el insert por el check constraint).
export function normalizaNBarberos(texto) {
  const t = texto.toLowerCase();
  if (/\bsolo\s*yo\b|\bsoy\s*yo\b|\buno\b|\b1\b/.test(t)) return 'Solo yo';
  const n = (t.match(/\d+/) || [])[0];
  if (n) {
    const num = parseInt(n, 10);
    if (num <= 1) return 'Solo yo';
    if (num <= 3) return '2-3';
    if (num <= 6) return '4-6';
    return '7 o más';
  }
  return null;
}

export function pareceSkipCorreo(texto) {
  return /^(no|no tengo|paso|skip|ninguno|prefiero no)\b/i.test(texto.trim());
}

// registra la prueba gratis por el mismo Formspree que usa el formulario
// de la landing, para no duplicar el intake en dos sistemas distintos.
export async function registraPruebaGratisFormspree({ nombreBarberia, comuna, telefonoCompleto, cantidadBarberos, correo }) {
  const body = new URLSearchParams({
    formulario: 'prueba-gratis-whatsapp',
    nombre_barberia: nombreBarberia || '',
    comuna: comuna || '',
    telefono_completo: telefonoCompleto,
    cantidad_barberos: cantidadBarberos || '',
    correo: correo || '',
    comentario: 'Agendada por el asistente de ventas por WhatsApp.',
  });
  const res = await fetch('https://formspree.io/f/xnpaegbe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body,
  });
  if (!res.ok) throw new Error(`Formspree: ${res.status} ${await res.text()}`);
}

// separa el texto visible del tag de control [[AGENDAR_LLAMADA: ...]]
export function extraeAgendarLlamada(textoCompleto) {
  const match = textoCompleto.match(/\[\[AGENDAR_LLAMADA:\s*motivo=(.*?);\s*resumen=(.*?)\]\]/s);
  const visible = textoCompleto.replace(/\s*\[\[AGENDAR_LLAMADA:.*?\]\]\s*$/s, '').trim();
  if (!match) return { visible, agendarLlamada: null };
  return { visible, agendarLlamada: { motivo: match[1].trim(), resumen: match[2].trim() } };
}
