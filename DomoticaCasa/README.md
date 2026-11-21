# Domótica Casa — iPad

Primera base SwiftUI para iPad mini 6 (iPadOS 17 o posterior).

## Abrir
1. Descarga esta rama como ZIP desde GitHub:
   https://github.com/eLTouca/control-horario-ios./archive/refs/heads/domotica-casa-ipad-v1.zip
2. Descomprime el ZIP y abre `DomoticaCasa.xcodeproj`.
3. Selecciona tu iPad mini 6 y ejecuta.

## Qué incluye esta primera versión
- Panel principal con resumen del hogar.
- Estancias con interruptores de demostración.
- Escenas rápidas editables en memoria.
- Apartado de conexiones para Tuya/Smart Life, Tapo, SmartThings y Apple Casa.
- Ajustes básicos del hogar.

## Importante
Los interruptores y escenas son una maqueta funcional local: cambian el estado visual dentro de la app, pero todavía **no controlan dispositivos físicos**. Las integraciones reales se añadirán por marca, utilizando los mecanismos oficiales disponibles. No hay servidor propio ni se presupone que iCloud actúe como puente de control remoto.

La sincronización familiar mediante iCloud queda como siguiente fase; esta versión no sube datos ni solicita credenciales.
