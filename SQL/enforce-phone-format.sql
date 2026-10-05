-- Ambas apps (cliente y dashboard) ahora arman el teléfono como
-- "+56 9 XXXX XXXX" a partir de un prefijo fijo + 8 dígitos ingresados por
-- el usuario. Se endurece el constraint para que ese sea el único formato
-- válido, no solo una validación cosmética en el frontend.

-- NOT VALID: hay reservas de prueba ya cargadas con teléfonos en el
-- formato viejo. Esto exige el formato nuevo para toda fila insertada o
-- actualizada de ahora en adelante, sin fallar por las filas existentes.
alter table bookings drop constraint if exists bookings_customer_phone_check;
alter table bookings add constraint bookings_customer_phone_check
  check (customer_phone ~ '^\+56 9 \d{4} \d{4}$') not valid;
