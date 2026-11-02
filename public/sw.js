// Service worker mínimo, solo para que Chrome/Android ofrezca "Agregar a
// inicio" en pantalla completa. A propósito NO cachea nada: cada carga del
// panel sigue pidiendo todo a la red, para no arriesgar datos viejos de
// citas/horarios (eso es lo que pidió la mejora: "sin caché agresiva de
// datos"). Si el navegador no manda un evento 'fetch' al SW, igual lo deja
// pasar directo a la red (comportamiento por defecto sin un handler).
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
