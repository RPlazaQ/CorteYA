-- Agrega el plan de cada barbería, para poder activar/desactivar funciones
-- pagadas a mano (WhatsApp, prepago) más adelante, cuando esas funciones
-- existan. Por ahora es solo el campo — no hay nada que gatear todavía,
-- ni WhatsApp ni prepago están implementados aún.
--
-- Valor por defecto 'piloto': todas las barberías que se suman ahora, hasta
-- el 22/09, entran como piloto. Rodrigo lo cambia a mano en el SQL Editor
-- cuando cada una confirma que sigue (o a 'inactivo' si no continúa).

alter table barbershops add column if not exists plan text not null default 'piloto';

alter table barbershops drop constraint if exists barbershops_plan_check;
alter table barbershops add constraint barbershops_plan_check
  check (plan in ('piloto', 'barbero_independiente', 'multisucursal', 'local_independiente', 'inactivo'));
