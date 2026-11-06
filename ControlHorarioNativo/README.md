# Control horario — proyecto iOS nativo

Este proyecto Xcode envuelve la aplicación actual en una app iOS y añade un puente nativo de Core Location. Al pulsar «Localizarme», iOS muestra el permiso del sistema y la app recibe las coordenadas y precisión GPS. El mapa de OpenStreetMap que ya incluye la aplicación permite confirmar el centro antes de guardarlo.

## Abrir y compilar
1. En un Mac, instala Xcode desde la Mac App Store.
2. Descomprime este paquete y abre `ControlHorario.xcodeproj`.
3. En el target **ControlHorario** > **Signing & Capabilities**, selecciona tu equipo (Team). Cambia el Bundle Identifier si Xcode indica que ya existe.
4. Conecta el iPhone por cable o activa el emparejamiento inalámbrico, selecciona el iPhone como destino y pulsa Run.
5. En el iPhone, concede «Permitir mientras se usa la app» cuando se solicite la ubicación.

## Publicación en App Store
Necesitas una cuenta Apple Developer individual o de organización. El titular debe completar la identidad, aceptar contratos y pagar la cuota directamente a Apple. Después, en Xcode se configura firma y se envía la compilación a App Store Connect para revisión.

## Importante
- Este paquete es el proyecto fuente, no un `.ipa` firmado ni una app ya instalada.
- La compilación y la firma para iPhone requieren macOS y Xcode; este entorno no dispone de Xcode/macOS, por lo que no puedo producir ni verificar un binario instalable desde aquí.
- La app pide ubicación «mientras se usa». No promete seguimiento GPS con la app cerrada o en segundo plano.
- El HTML conserva sus datos en el almacenamiento local del WebView. No borres la app sin exportar antes los datos desde sus opciones, si están disponibles.
