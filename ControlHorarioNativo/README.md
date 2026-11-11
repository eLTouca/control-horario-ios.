# Control horario — proyecto iOS nativo

Este proyecto Xcode envuelve la aplicación actual en una app iOS y añade un puente nativo de Core Location. Al pulsar «Localizarme», iOS muestra el permiso del sistema y la app recibe las coordenadas y precisión GPS. El mapa de OpenStreetMap que ya incluye la aplicación permite confirmar el centro antes de guardarlo.

## Abrir y compilar
1. En un Mac, instala Xcode desde la Mac App Store.
2. Descomprime este paquete y abre `ControlHorario.xcodeproj`.
3. En el target **ControlHorario** > **Signing & Capabilities**, selecciona tu equipo (Team). Cambia el Bundle Identifier si Xcode indica que ya existe.
4. Conecta el iPhone por cable o activa el emparejamiento inalámbrico, selecciona el iPhone como destino y pulsa Run.
5. En el iPhone, concede el permiso de ubicación y después selecciona **Siempre** en Ajustes > Privacidad y seguridad > Localización > Control horario. Activa también **Ubicación precisa**.

## Publicación en App Store
Necesitas una cuenta Apple Developer individual o de organización. El titular debe completar la identidad, aceptar contratos y pagar la cuota directamente a Apple. Después, en Xcode se configura firma y se envía la compilación a App Store Connect para revisión.

## Importante
- Este paquete es el proyecto fuente, no un `.ipa` firmado ni una app ya instalada.
- La compilación y la firma para iPhone requieren macOS y Xcode; este entorno no dispone de Xcode/macOS, por lo que no puedo producir ni verificar un binario instalable desde aquí.
- La app utiliza una geovalla nativa de Core Location: iOS vigila la zona sin mantener el GPS continuo y puede despertar la app cuando detecta una entrada o salida, incluso si el proceso fue terminado. No se ejecuta un contador JavaScript segundo a segundo mientras la app está suspendida; al recibir el evento de salida se recupera el intervalo completo usando las marcas de tiempo guardadas.
- Para que funcione en segundo plano, la autorización debe ser **Siempre**, los Servicios de localización deben estar activos y Ajustes > General > Actualización en segundo plano debe permitir Control horario. Si el iPhone se reinicia, abre la app una vez para que vuelva a registrar la geovalla.
- La detección depende de las señales de ubicación de iOS y del radio configurado. En entornos con mala cobertura o edificios, una geovalla demasiado pequeña puede tardar o no detectar el límite con precisión; aumenta el radio si observas retrasos.
- El HTML conserva sus datos en el almacenamiento local del WebView. No borres la app sin exportar antes los datos desde sus opciones, si están disponibles.
