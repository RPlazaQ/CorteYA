// Sirve el archivo .ics como una respuesta HTTP real (no un blob: generado en el
// navegador). Safari en iPhone solo abre el diálogo nativo "Agregar evento" cuando
// el archivo llega por una URL de verdad con el Content-Type correcto; con un blob:
// terminaba ofreciendo "Guardar en Archivos" en vez de abrir el Calendario.

export default async (request) => {
  const url = new URL(request.url);
  const content = url.searchParams.get('content') || '';

  return new Response(content, {
    status: 200,
    headers: {
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': 'inline; filename="reserva-corteya.ics"',
      'Cache-Control': 'no-store',
    },
  });
};

export const config = {
  rateLimit: {
    action: 'rate_limit',
    aggregateBy: 'ip',
    windowSize: 60,
    windowLimit: 20,
  },
};
