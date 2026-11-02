# Tasas de cambio y calculadora Android

## Arquitectura comprobada
El repositorio móvil local corresponde a cperdomo007/nota-entrega-mobile. La aplicación web se revisó en el proyecto padre (remoto v3 configurado). El backend móvil existente es Node 22 + Express 5, no ASP.NET Core. Se reutilizan su sesión Bearer, middleware de autorización, Dio y Riverpod. No se cambia la web ni el cálculo de notas/presupuestos. No se crean tablas ni migraciones MySQL.

## Fuentes y metodología
BCV: HTTPS https://www.bcv.org.ve/ . Se extraen exclusivamente el bloque dolar y su fecha publicada. Una respuesta sin valor positivo o sin fecha válida se rechaza. La fecha de vigencia y la fecha de consulta son diferentes campos. El backend nunca omite validación TLS. En la comprobación local del 02/11/2026 el certificado devolvió UNABLE_TO_VERIFY_LEAF_SIGNATURE; la integración debe verificarse en el entorno desplegado. Si ocurre allí, configurar la cadena CA legítima con NODE_EXTRA_CA_CERTS o corregir la fuente; nunca NODE_TLS_REJECT_UNAUTHORIZED=0.

Binance: API pública documentada en https://www.binance.com/en-PH/skills/detail/binance/p2p .
Primero consulta trade-methods?fiat=VES y valida el identificador de pago. Luego consulta ad-list para asset=USDT, fiat=VES, tradeType=BUY (el usuario compra USDT pagando VES), limit=5, order=asc y tradeMethodIdentifiers=PagoMovil. La referencia de pago es Pago Móvil; puede configurarse BINANCE_PAYMENT_METHOD en servidor con otro identificador válido.
Solo acepta anuncios de ese activo, moneda y método. Se toma la mediana de los primeros cinco anuncios elegibles (mínimo tres). No representa una oferta ejecutable, incluye anuncios con límites distintos y no garantiza disponibilidad para un monto concreto.
El backend almacena SIEMPRE la base sin ajustar. La tasa final se deriva: base + 6.000000. BCV tiene ajuste cero. Flutter valida la igualdad y nunca añade nuevamente el ajuste. No se generan operaciones, órdenes ni pagos Binance. No se requieren claves privadas.

## Contrato
GET /api/mobile/v1/exchange-rates, con Bearer de la sesión actual. Mantiene HTTPS obligatorio y límites existentes.
Respuesta: rates.bcv y rates.binance, cada uno objeto o null si nunca hubo una cotización válida. Campos: id, baseRate, rate, adjustment (strings decimales exactos, 6 posiciones), updatedAt (última consulta válida UTC), source, stale. BCV agrega effectiveAt. Binance agrega tradeType, paymentMethod, sampleSize, methodology.
Incluye serverTime y cacheSeconds=300. Nunca se envían anuncios, nombres de vendedores ni credenciales al dispositivo.

## Caché y fallos
Consulta al ingresar al panel y con el botón Actualizar. Caché del servidor: cinco minutos; mínimo treinta segundos entre intentos fallidos. Solicitudes simultáneas comparten una consulta. Botón manual respeta estos límites. Cada fuente falla independientemente: se conserva su último valor con stale=true. Sin valor previo retorna null y la calculadora de esa tasa queda sin resultado.
EXCHANGE_CACHE_FILE permite elegir el archivo de caché de servidor (por defecto .cache/exchange-rates.json). El contenedor prepara ese directorio para el usuario node. Para conservarlo entre despliegues se necesita un volumen persistente y configurar una ruta allí; un archivo efímero solo sobrevive reinicios del proceso en el mismo filesystem.
Flutter conserva cotizaciones en almacenamiento local por origen API; al recuperar de disco las marca desactualizadas hasta confirmar una consulta nueva. Fallos de almacenamiento no sustituyen valores válidos.
La UI muestra hora de Venezuela UTC-4, estado de carga, indisponibilidad y antigüedad. No se muestran variaciones ficticias de precio; la referencia visual solo guía el diseño.

## Precisión
BigInt con seis decimales en entrada y tasas. Resultado monetario con dos decimales y redondeo half-up. No se usa double para operaciones monetarias. Entrada positiva o cero, hasta 15 dígitos enteros y seis decimales, coma o punto decimal sin agrupadores en el campo editable. Resultado seleccionable y copiable con miles y coma decimal. Tasas cero o inválidas se rechazan; no hay eval de expresiones.
ExchangeRateModel.toJson conserva la tasa efectiva, tipo y fecha como snapshot reutilizable para futuros documentos; aún no se guarda en documentos existentes.

## Validación y Android
Backend: cd backend; npm test.
Flutter: flutter analyze --no-pub; flutter test --no-pub.
APK de pruebas: flutter build apk --debug --dart-define-from-file=config/env.production.json.
Instalar el APK actualizado en Android y desplegar primero el backend con el endpoint nuevo. Un APK anterior no incorpora el panel. No se publica ni despliega automáticamente con este cambio.
Pruebas del módulo: fuente BCV, filtro y mediana Binance, ajuste exacto único, caché, fallo, persistencia, conversiones bidireccionales, validación de importes, selector y layout a 320 y 600 píxeles. Revisar también en dispositivo: teclado Android, portapapeles y accesibilidad con escala de texto.

## Archivos principales
- lib/domain/exchange_rate.dart: modelo inmutable y aritmética decimal.
- lib/data/exchange_rate_service.dart: consulta autenticada, persistencia y notificaciones.
- lib/ui/exchange_rates.dart: tarjetas, selector, calculadora y estado Riverpod.
- lib/ui/screens.dart: inserción debajo de Crear nota de entrega.
- backend/src/exchange-rates.js y backend/src/app.js: fuentes, caché y endpoint.
- backend/Dockerfile y backend/.env.example: almacenamiento/configuración del caché.
- test/exchange_* y backend/test/exchange-rates.test.js: pruebas funcionales y de interfaz; flutter_test_config.dart simula almacenamiento seguro para la suite.

La vista previa build/exchange-preview.png se genera con datos ficticios explícitos de prueba. No es una captura de cotizaciones actuales. La referencia visual no se incorpora como una cotización.

Validación local 02/11/2026: la consulta real de Binance respondió con cinco anuncios y ajuste de exactamente Bs 6. BCV no se pudo validar en vivo por la cadena TLS de la fuente. La compilación APK se intentó y se detuvo porque este equipo no tiene Android SDK configurado; no se generó un APK nuevo ni se desplegó el backend.

## Respaldo BCV vía DolarVZLA (02/11/2026)

Si BCV falla o publica una cotización aún no vigente, se consulta la API pública documentada en https://dolarvzla.com/settings/api : https://rates.dolarvzla.com/bcv/current.json . No requiere clave. Se valida USD positivo, fecha real, vigencia según America/Caracas y antigüedad máxima de siete días. Se selecciona la más reciente vigente entre current y previous; una tasa publicada para mañana no se usa hoy. Se muestra BCV vía DolarVZLA y su fecha de vigencia; el contrato conserva source y effectiveAt. Esta es una fuente secundaria, no una conexión directa al BCV. Los datos se consultan con caché, se atribuyen al proveedor y no se presentan como propios. Binance continúa usando su API pública directa y ajuste de Bs 6. No se genera ninguna API key ni se incorpora publicidad.

Se verificó una respuesta HTTPS real del CDN de DolarVZLA. La consulta actual de BCV puede resolverse ahora mediante ese respaldo, conservando TLS estricto.
