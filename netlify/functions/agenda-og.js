// Página intermedia para links compartidos (WhatsApp/Instagram/etc).
// Los crawlers de redes sociales no ejecutan JS: leen las etiquetas <meta>
// del HTML crudo. Esta función busca el nombre real de la barbería y arma
// esas etiquetas antes de redirigir al humano hacia la app de verdad.

const SUPABASE_URL = 'https://dpdrtvbvjmcdyjidszcc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwZHJ0dmJ2am1jZHlqaWRzemNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3MDkwMjQsImV4cCI6MjEwMzI4NTAyNH0.v_IRqYk62gjlS9mmRllK3xE0Y3V0fOHn2SMkKaA-zJE';
const DEFAULT_IMAGE = 'https://corteya.app/screenshots/app-cliente-lista.png';

function escapeHtml(str) {
  return String(str ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

exports.handler = async (event) => {
  const slug = event.queryStringParameters?.slug || '';
  let name = 'CorteYa';
  let imageUrl = DEFAULT_IMAGE;

  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/barbershops?slug=eq.${encodeURIComponent(slug)}&select=name,image_url`,
      { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` } }
    );
    const rows = await res.json();
    if (Array.isArray(rows) && rows[0]) {
      name = rows[0].name || name;
      if (rows[0].image_url) imageUrl = rows[0].image_url;
    }
  } catch (e) {
    // si Supabase falla, seguimos con los valores por defecto
  }

  const title = `${name} — Agenda tu hora`;
  const targetUrl = `/app-cliente.html?barberia=${encodeURIComponent(slug)}`;

  const html = `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escapeHtml(title)}</title>
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="Reserva tu hora en ${escapeHtml(name)} con CorteYa.">
<meta property="og:type" content="website">
<meta property="og:image" content="${escapeHtml(imageUrl)}">
<meta name="twitter:card" content="summary">
<meta http-equiv="refresh" content="0; url=${escapeHtml(targetUrl)}">
</head>
<body>Redirigiendo…</body>
</html>`;

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
    body: html,
  };
};
