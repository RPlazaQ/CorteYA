// Sirve el archivo .ics como una respuesta HTTP real (no un blob: generado en el
// navegador). Safari en iPhone solo abre el diálogo nativo "Agregar evento" cuando
// el archivo llega por una URL de verdad con el Content-Type correcto; con un blob:
// terminaba ofreciendo "Guardar en Archivos" en vez de abrir el Calendario.

exports.handler = async (event) => {
  const content = event.queryStringParameters?.content || '';

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': 'inline; filename="reserva-corteya.ics"',
      'Cache-Control': 'no-store',
    },
    body: content,
  };
};
