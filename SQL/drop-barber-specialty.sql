-- Elimina la columna 'specialty' de barbers: ya no se usa en ninguna
-- pantalla (se sacó del dashboard de la barbería).

alter table barbers drop column if exists specialty;
