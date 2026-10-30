# API móvil v1 implementada

Código en `backend/src/`. Base HTTPS `/api/mobile/v1/`; MySQL solo en el servidor. Datos JSON camelCase, precios como strings decimales y fechas YYYY-MM-DD. No envolver en SuperJSON/tRPC.

## Autenticación

- POST `auth/login`: `{email,password}` → `{accessToken,refreshToken,expiresIn:900,user:{id,email,name,role}}`.
- POST `auth/refresh`: `{refreshToken}` → misma estructura, rotando access/refresh; los anteriores dejan de funcionar.
- POST `auth/logout`: `{refreshToken}` → 204, revoca la sesión. Es idempotente.
- GET `auth/me`: requiere Bearer → `{user}`.

Las cuentas residen en `mobile_users`, separadas de `users` OAuth de la web. Contraseñas de 12–128 caracteres al crearlas; scrypt N=32768,r=8,p=3, salt aleatorio de 16 bytes. Tokens opacos de 32 bytes aleatorios; solo hashes SHA-256 en `mobile_sessions`. Cinco fallos por cuenta bloquean 15 minutos. Respuestas de login uniformes sin revelar si existe la cuenta. Rate limiting por IP (una réplica); bloqueo de cuenta persistente entre réplicas.

Todas las rutas siguientes requieren `Authorization: Bearer <accessToken>`. Se comprueba usuario activo y expiración en cada solicitud, sin reutilizar cookies web.

| Método/ruta | Respuesta |
| --- | --- |
| GET dashboard | `{clients,products,notes}` conteos reales |
| GET clients?q=&limit=50&offset=0 | `{items:[{id,name,rif,address,phone,email,contact}]}` |
| GET products?q=&limit=50&offset=0 | `{items:[{id,name,barcode,description,category,price,unit,hasSerial,stock}]}` |
| GET notes?q=&limit=50&offset=0 | `{items:[{id,noteNumber,noteDate,clientName,subtotal,ivaAmount,total,applyIVA}]}` |
| GET config | `{businessName,ivaRate}` |
| GET notes/next-number | `{noteNumber}` sugerencia NE-000001, no reserva |
| GET notes/:id | Cabecera, companyName y lines con productName/serials como strings |
| POST notes | 201 `{id,noteNumber?}` |
| GET users | Solo admin; `{items:[{id,email,name,role,active}]}` paginado |
| POST users | Solo admin; `{email,name,password,role}` → 201 usuario sin hash |
| PATCH users/:id | Solo admin; `{active:boolean}` → 204; desactivar revoca sesiones |

No se permite desactivar la propia cuenta. No hay endpoint público de registro. Para crear el primer administrador se usa el comando del servidor documentado en RAILWAY.md.

Búsqueda por nombre/RIF, nombre/código y número/cliente. Limit 1–50, offset>=0, orden id descendente; comodines escapados. hasSerial/applyIVA booleanos; datos de la misma empresa compartidos para todas las cuentas activas.

POST notes usa `Idempotency-Key` (24–96 caracteres A–Z, a–z, dígitos, _ y -). Ejemplo de cuerpo:

```json
{"noteNumber":"NE-000001","noteDate":"2026-10-30","clientName":"Cliente","clientRif":"J-1","clientAddress":"","clientPhone":"","clientContact":"","applyIVA":true,"ivaRate":"16.00","observations":"","deliveredBy":"","receivedBy":"","lines":[{"productId":1,"quantity":1,"unitPrice":"100.25","serials":["ABC"]}]}
```

Valida productos existentes, cantidades enteras, precios/rangos, fecha válida y seriales; serial único dentro de la nota y uno por unidad para hasSerial. La tasa se lee de company_config y se recalculan subtotal, IVA y total en centavos. Una tasa cliente desactualizada devuelve 409. Nota, líneas, seriales y respuesta idempotente se confirman en una misma transacción. Misma clave/usuario/cuerpo devuelve el mismo id; otro cuerpo con esa clave devuelve 409. Número único validado por BD; no sobrescribe notas existentes. No hay reintento automático de POST.

Errores: 400 JSON inválido, 401 credenciales/sesión, 403 permisos, 404 ausente, 409 conflicto, 413 cuerpo grande, 422 validación, 426 HTTPS, 429 límite, 5xx error. SQL y credenciales nunca se devuelven. TLS termina en Railway; un proxy de ingreso confiable. /health solo responde disponibilidad de BD; no expone información del esquema.

Despliegue autorizado: https://nota-entrega-mobile-production.up.railway.app/api/mobile/v1/ . La API es pública por HTTPS, las rutas de datos requieren sesión y API→MySQL usa red privada. No se habilitó HTTP ni conexión MySQL en Flutter.
