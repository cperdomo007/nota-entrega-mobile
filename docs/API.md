# Contrato propuesto del adaptador móvil v1

**Pendiente de implementación/aprobación en servidor.** Estos endpoints NO se encontraron en la web. No hay despliegue ni migración en esta entrega. El adaptador debe reutilizar servicios/transacciones web contra los mismos datos, sin exponer MySQL a Flutter.

Base HTTPS `/api/mobile/v1/`. JSON UTF-8, camelCase. Autenticación obligatoria `Authorization: Bearer <access_token>` en todas las rutas; validar firma, issuer, audience, expiración y usuario/roles. OIDC Authorization Code + PKCE S256, cliente público Android y redirect registrado. El proveedor debe vincular identidades con users.openId existente mediante un mecanismo aprobado, sin crear asociaciones por email no verificado. No aceptar JWT de la cookie como token móvil por defecto. Sin client_secret embebido.

| Método/ruta | Respuesta |
| --- | --- |
| GET dashboard | `{"clients":10,"products":20,"notes":30}` |
| GET clients?q=&limit=50&offset=0 | `{"items":[{"id":1,"name":"Cliente","rif":"J-1","address":"","phone":"","contact":""}]}` |
| GET products?q=&limit=50&offset=0 | `{"items":[{"id":1,"name":"Router","barcode":"123","price":"100.25","unit":"UN","hasSerial":true}]}` |
| GET notes?q=&limit=50&offset=0 | `{"items":[{...cabecera}]}` |
| GET config | `{"ivaRate":"16.00"}` |
| GET notes/next-number | `{"noteNumber":"NE-000001"}` (sugerencia) |
| GET notes/:id | Cabecera y `lines` con productId, productName, quantity, unitPrice, lineTotal y serials (array de strings, normalizar objetos web) |
| POST notes | 201 `{"id":1,"noteNumber":"NE-000001"}` |

Búsqueda clientes por nombre/RIF, productos por nombre/código (código exacto primero), notas por número/cliente. Orden estable por id; máximo 50, offset>=0; última página tiene menos de 50 elementos. Importes como cadenas con dos decimales; fechas YYYY-MM-DD; hasSerial/applyIVA booleanos. No envolver en result/data ni SuperJSON.

POST notes incluye `Idempotency-Key` opaco (24 bytes aleatorios hex). Payload:

```json
{"noteNumber":"NE-000001","noteDate":"2026-10-30","clientName":"Cliente","clientRif":"J-1","clientAddress":"","clientPhone":"","clientContact":"","applyIVA":true,"ivaRate":"16.00","observations":"","deliveredBy":"","receivedBy":"","lines":[{"productId":1,"quantity":1,"unitPrice":"100.25","serials":["ABC"]}]}
```

Recalcular todos los totales y validar productos, permisos de precio, tasa fiscal permitida, límites decimales, longitudes, fecha y reglas de WEB_ANALYSIS. Guardar instantánea del cliente. Número único en transacción. Idempotencia persistida y vinculada al usuario+ruta+hash del payload; misma clave/cuerpo devuelve mismo id; misma clave con otro cuerpo devuelve 409. La operación y registro idempotente deben ser atómicos. El cliente no vuelve a enviar automáticamente POST. Reintentar el mismo formulario conserva la clave; cambiar el cuerpo tras un resultado incierto produce 409 hasta resolverlo.

Detalle: `id,noteNumber,noteDate,clientName,clientRif,clientAddress,clientPhone,subtotal,ivaAmount,total,applyIVA,observations,deliveredBy,receivedBy,companyName,lines`. En PDF se usan importes persistidos, no estimaciones móviles.

Errores: 401 sesión expirada (cierre local), 403 no autorizado, 404 nota ausente, 409 conflicto/número/idempotencia, 422 validación, 429 límite, 5xx fallo. UI muestra mensaje genérico sin exponer SQL/tokens. Adaptador debe aplicar rate limiting, auditoría sin secretos, autorización y aislamiento de datos, consultas parametrizadas y TLS válido. No reenviar cookies de producción ni deshabilitar certificados.

Pruebas de aceptación de servidor pendientes: acceso anónimo rechazado en cada ruta; token inválido/expirado/audience incorrecta; permisos y cruce de usuarios; paginación; totales y seriales; rollback; doble POST concurrente con misma clave; conflictos de número y redondeo; datos web visibles en móvil y nota móvil visible en web en staging.
