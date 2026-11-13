-- Soporte de "modo flujo fijo" para el asistente de ventas, mientras no
-- haya créditos de la API de Claude cargados (ver prompt-whatsapp-ventas.md).
-- Guarda en qué paso del formulario de prueba gratis va cada lead, para
-- poder sostener una conversación de varios turnos sin usar un modelo.

alter table whatsapp_leads add column if not exists flujo_prueba_paso text
  check (flujo_prueba_paso in ('nombre', 'comuna', 'n_barberos', 'correo'));
