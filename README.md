# Nota Entrega Mobile

Aplicación Android Flutter/Dart con Material 3, Riverpod, GoRouter y Dio. El acceso utiliza correo y contraseña a través de una API HTTPS propia en `backend/`.

## Ejecutar el cliente

1. Flutter 3.47.9 / Dart 3.13.7, JDK 17 y Android SDK.
2. `flutter pub get`
3. La URL autorizada está en `config/env.production.json`: `https://nota-entrega-mobile-production.up.railway.app/api/mobile/v1/`. Para otro entorno, copiar `config/env.example.json` a `config/env.local.json`.
4. `flutter run --dart-define-from-file=config/env.production.json`

Flutter no contiene acceso directo a MySQL ni credenciales de BD. La única variable compilada es `API_BASE_URL`, pública. OAuth/OIDC del prototipo fue sustituido por acceso con usuarios propios; el acceso OAuth de la web permanece independiente.

## Servidor y datos compartidos

`backend/` implementa autenticación, sesiones revocables, administración de usuarios y el contrato de datos de clientes/productos/notas/presupuestos. Se conecta a la BD de la web desde el servidor. Consultar [despliegue Railway](docs/RAILWAY.md) y [contrato API](docs/API.md).

La migración agrega exclusivamente `mobile_users`, `mobile_sessions` y `mobile_note_requests`. No altera `users` ni las tablas de negocio existentes. No se ejecutan migraciones desde Flutter. El primer administrador y su contraseña se establecen privadamente mediante el comando de creación de usuario. No existe registro público ni una contraseña predeterminada.

Las sesiones usan access tokens aleatorios de 15 minutos en memoria, refresh tokens rotatorios de 30 días en almacenamiento seguro y hashes de ambos tokens en MySQL. Un 401 cierra la sesión local. Al reabrir la app se intenta renovar. Cerrar sesión revoca el refresh token en el servidor cuando hay conexión. Sin conexión, se elimina localmente y la sesión remota caduca por expiración. No se almacenan contraseñas en Flutter. HTTPS obligatorio; no hay logs de tokens ni contraseñas.

## Funcionalidades

- Inicio de sesión con correo/contraseña y recuperación de sesión.
- Dashboard, clientes y productos con búsqueda/paginación y alta desde el listado o el selector de un documento.
- Listado, creación y detalle de notas; seriales manuales y cámara.
- Consulta, búsqueda y creación de presupuestos con descripción editable, detalle y PDF compartido. Sin edición ni eliminación de documentos existentes.
- PDF A4 de Presupuesto y Nota de Entrega según los formatos facilitados, con logo, datos fiscales, cliente, observaciones y totales; firmas en notas. Sin códigos de producto en las líneas, conservando los seriales. Fuentes incluidas y soporte multipágina. Ver [formatos PDF](docs/PDF_FORMATS.md).
- API: creación/desactivación de usuarios solo por administradores; cuentas desactivadas pierden acceso y sesiones.

Todos los usuarios activos pertenecen a la misma empresa y comparten su catálogo y notas; no hay aislamiento multiempresa. Los totales definitivos se calculan en el servidor según el IVA configurado. El precio unitario es editable por usuarios autorizados a crear notas, como en la web. No se agrega descuento automático de stock.

Desde 0.4.0+6, notas y presupuestos reciben al guardar un número DDMMAAAAHHMM con la hora de Venezuela (por ejemplo, 301020261710). No se utiliza MAX(id), NE- ni un contador. La vista previa no reserva el número. Si ya existe un documento del mismo tipo en ese minuto, se informa un conflicto y se debe esperar al minuto siguiente; un reintento de la misma operación confirmada recupera su ID. No se renumeran documentos existentes. DOCUMENT_TIME_ZONE, solo en el servidor, usa America/Caracas por defecto.

## Pruebas y compilación

`flutter analyze --no-pub`, `flutter test --no-pub --coverage`, `flutter build apk --debug --dart-define-from-file=config/env.local.json`.

En `backend/`: `npm ci`, `npm test`. La integración usa `TEST_DATABASE_URL` exclusivamente con una base descartable cuyo nombre termine en `_test`: `npm run test:integration`. Nunca ejecutar fixtures de prueba sobre Railway producción.

GitHub Actions analiza y prueba Flutter, compila APK optimizados por arquitectura con config/env.production.json, prueba el backend con MySQL 8.4 aislado y construye su Dockerfile. Consultar el resultado de la ejecución del commit correspondiente; no confundir APKs anteriores con el nuevo login.

Las pruebas Flutter exportan seis documentos ficticios en `build/pdf-preview/`. Para comprobar su texto real: `python -m pip install pypdf==6.10.0` y `python tool/verify_pdf.py`. CI verifica formatos, importes, IVA, paginación y seriales; rechaza códigos/IDs de producto impresos. Publica dos ejemplos ficticios como `pdf-format-previews`. Los PDF de clientes facilitados como referencia no forman parte del repositorio.

## Estado

Ver `docs/VALIDATION.md`. La API y la migración ya fueron desplegadas en Railway con autorización. La API está publicada por HTTPS con autorización expresa del propietario y el APK se configura con esa URL. Las rutas de datos exigen sesión; la conexión del backend a MySQL continúa usando la red privada de Railway. El propietario confirmó el alta del administrador y la contraseña se estableció fuera del chat. El login de producción en un teléfono todavía requiere comprobación manual. Pendientes de verificación en dispositivo: cámara/permisos, compartir PDF y revisión visual. La compilación optimizada usa firma de prueba; firma de producción y distribución en Play Store pendientes.


## Descargas optimizadas (0.4.1+7)

CI ejecuta `flutter build apk --release --split-per-abi --dart-define-from-file=config/env.production.json`. Cada descarga contiene únicamente las bibliotecas de una arquitectura: `nota-entrega-optimized-arm64` (ARM 64 bits), `nota-entrega-optimized-arm32` (ARM 32 bits) o `nota-entrega-optimized-x86_64` (x86 de 64 bits). No instalar las tres: elegir la correspondiente al dispositivo. Los modos release activan las optimizaciones de Dart y el SDK Flutter configura minificación/recorte de recursos. Se conservan cámara, PDF, fuentes y logo.

Estos APK son instalables y optimizados para pruebas, firmados con la clave debug del runner; no representan una firma de producción ni se publican en Play Store. La identidad de esa clave puede cambiar entre ejecuciones de CI, como en los APK debug anteriores. La firma de producción requiere configuración aparte.

`tool/apk_report.py` verifica una única ABI, código AOT y ausencia del kernel debug en cada archivo, mide los bytes reales y publica `apk-size-report` y una tabla en el resumen de CI. CI verifica además las firmas, que debuggable=false y el permiso INTERNET en los APK finales. No afirmar tamaño ni compilación exitosa hasta verificar el run correspondiente.
