# Nota Entrega Mobile

Aplicación Android Flutter/Dart con Material 3, Riverpod, GoRouter y Dio. El acceso utiliza correo y contraseña a través de una API HTTPS propia en `backend/`.

## Ejecutar el cliente

1. Flutter 3.47.9 / Dart 3.13.7, JDK 17 y Android SDK.
2. `flutter pub get`
3. Copiar `config/env.example.json` a `config/env.local.json` y definir `API_BASE_URL` con la URL HTTPS de la API terminada en `/api/mobile/v1/`.
4. `flutter run --dart-define-from-file=config/env.local.json`

Flutter no contiene acceso directo a MySQL ni credenciales de BD. La única variable compilada es `API_BASE_URL`, pública. OAuth/OIDC del prototipo fue sustituido por acceso con usuarios propios; el acceso OAuth de la web permanece independiente.

## Servidor y datos compartidos

`backend/` implementa autenticación, sesiones revocables, administración de usuarios y el contrato de datos de clientes/productos/notas. Se conecta a la BD de la web desde el servidor. Consultar [despliegue Railway](docs/RAILWAY.md) y [contrato API](docs/API.md).

La migración agrega exclusivamente `mobile_users`, `mobile_sessions` y `mobile_note_requests`. No altera `users` ni las tablas de negocio existentes. No se ejecutan migraciones desde Flutter. El primer administrador y su contraseña se establecen privadamente mediante el comando de creación de usuario. No existe registro público ni una contraseña predeterminada.

Las sesiones usan access tokens aleatorios de 15 minutos en memoria, refresh tokens rotatorios de 30 días en almacenamiento seguro y hashes de ambos tokens en MySQL. Un 401 cierra la sesión local. Al reabrir la app se intenta renovar. Cerrar sesión revoca el refresh token en el servidor cuando hay conexión. Sin conexión, se elimina localmente y la sesión remota caduca por expiración. No se almacenan contraseñas en Flutter. HTTPS obligatorio; no hay logs de tokens ni contraseñas.

## Funcionalidades

- Inicio de sesión con correo/contraseña y recuperación de sesión.
- Dashboard, clientes y productos con búsqueda/paginación.
- Listado, creación y detalle de notas; seriales manuales y cámara.
- PDF A4 multipágina con fuentes incluidas y selector nativo para compartir.
- API: creación/desactivación de usuarios solo por administradores; cuentas desactivadas pierden acceso y sesiones.

Todos los usuarios activos pertenecen a la misma empresa y comparten su catálogo y notas; no hay aislamiento multiempresa. Los totales definitivos se calculan en el servidor según el IVA configurado. El precio unitario es editable por usuarios autorizados a crear notas, como en la web. No se agrega descuento automático de stock.

## Pruebas y compilación

`flutter analyze --no-pub`, `flutter test --no-pub --coverage`, `flutter build apk --debug --dart-define-from-file=config/env.local.json`.

En `backend/`: `npm ci`, `npm test`. La integración usa `TEST_DATABASE_URL` exclusivamente con una base descartable cuyo nombre termine en `_test`: `npm run test:integration`. Nunca ejecutar fixtures de prueba sobre Railway producción.

GitHub Actions analiza y prueba Flutter, compila APK debug, prueba el backend con MySQL 8.4 aislado y construye su Dockerfile. Consultar el resultado de la ejecución del commit correspondiente; no confundir APKs anteriores con el nuevo login.

## Estado

Ver `docs/VALIDATION.md`. La API y la migración ya fueron desplegadas en Railway con autorización. La API se mantuvo privada por decisión del propietario: el APK no puede acceder desde Internet hasta configurar una VPN/pasarela privada HTTPS. El propietario debe establecer privadamente la contraseña inicial y completar el alta del administrador. Pendientes de verificación en dispositivo: cámara/permisos, compartir PDF y revisión visual. Firma/distribución release no configuradas.
