# EXPEDIENTE TÉCNICO DE DESARROLLO DE SOFTWARE

## 1. Información General del Proyecto
*   **Nombre del Proyecto:** BodeGo
*   **Eslogan:** Tecnología impulsada por eddamcore.com
*   **Desarrollador:** Corporación EddamCore
*   **Tipo de Aplicación:** Punto de Venta (POS) y Gestión de Inventario para Dispositivos Móviles y Tablets.
*   **Público Objetivo:** Pequeños y medianos emprendedores (bodegas, minimarkets, tiendas de abarrotes).
*   **Modelo de Operación:** Arquitectura *Offline-First* (75% operación local / 25% sincronización cloud).

---

## 2. Arquitectura y Stack Tecnológico
El sistema está diseñado para garantizar alta disponibilidad y velocidad de respuesta en el mostrador, eliminando la dependencia de una conexión a internet constante.

*   **Frontend (Aplicación Móvil):** Flutter (Soporte multiplataforma, optimizado para Android en tablets y smartphones).
*   **Base de Datos Local:** Isar Database (Motor NoSQL de alto rendimiento, consultas full-text, soporte asíncrono).
*   **Backend / Nube (Sincronización):** API REST alojada en infraestructura propia (desplegada vía Dokploy) para recepción de backups.
*   **Sistema de Actualizaciones (OTA):** Integración directa con **GitHub Releases**.

---

## 3. Módulos y Funcionalidades Principales

### 3.1. Onboarding y Seguridad Local
*   **Login Rápido:** Acceso mediante un PIN de 4 a 6 dígitos.
*   **Carrusel de Configuración Inicial (Wizard):** Configuración del nombre del negocio, logo, moneda base y pie de página para los tickets.

### 3.2. Módulo de Caja (Punto de Venta - POS)
*   Interfaz de cuadrícula rápida y buscador de productos en tiempo real.
*   Lector de códigos de barras integrado (vía cámara del dispositivo) y compatibilidad con escáneres externos (USB/Bluetooth).
*   Cálculo automático de subtotales, impuestos, descuentos y vuelto.

### 3.3. Módulo de Inventario y Catálogo
*   Gestión de categorías (Abarrotes, Lácteos, Limpieza, etc.).
*   Control de stock, alertas de inventario mínimo y registro de precios de compra/venta (Kardex simplificado).

### 3.4. Módulo de Clientes (Cuentas por Cobrar / "Fiados")
*   Registro de clientes frecuentes.
*   Asignación de créditos, registro de deudas, abonos parciales y liquidaciones.

### 3.5. Arqueo de Caja y Reportes
*   Reportes de apertura y cierre de caja.
*   Métricas de rendimiento: ganancias diarias, productos más vendidos y auditoría de medios de pago.

### 3.6. Configuración y Hardware (Impresión Térmica)
*   Conexión mediante comandos ESC/POS a impresoras térmicas (58mm y 80mm) vía Bluetooth y Wi-Fi LAN.
*   Impresión de comprobantes y reportes de cierre (Tickets Z).

---

## 4. Diseño de Interfaz y Experiencia de Usuario (UI/UX)
El sistema soporta personalización de temas para adaptarse a las preferencias del usuario, almacenando la configuración en Isar Database.

**Paleta de Colores Predeterminada (Tema BodeGo):**
*   **Background (Fondo):** `#F8F9FE` (Blanco Nieve/Azulado) - Reduce la fatiga visual.
*   **Surface (Tarjetas/Paneles):** `#E8EBFA` (Lavanda/Gris Claro) - Contenedores y divisiones.
*   **Primary (Acciones Principales):** `#4353FF` (Azul Rey Vibrante) - Botones de cobro y acciones críticas.
*   **Accent (Éxito/Finanzas):** `#4FD1C5` (Turquesa) - Precios, stock disponible.
*   **Text/On-Background (Tipografía):** `#141A3C` (Azul Noche Profundo) - Alta legibilidad.

**Tema Alternativo (EddamCore Dark):**
*   Fondos en `#000000` y `#1A1A1A` con acentos en Rojo Neón `#FF0033` corporativo de EddamCore.

---

## 5. Sistema de Actualizaciones OTA (Over-The-Air)
Para evitar que los usuarios tengan que gestionar descargas manuales o depender exclusivamente de tiendas de aplicaciones, BodeGo incorpora un actualizador interno:

1.  **Verificación de Versión:** Al arrancar (si hay conexión a internet), la app consulta la API de GitHub Releases del repositorio de BodeGo.
2.  **Comparación:** Compara el tag de la versión actual (ej. `v1.0.2`) con la última release pública (`v1.1.0`).
3.  **Descarga Directa (APK):** Si hay una actualización, muestra un *Dialog* informando las mejoras (Release Notes) y permite descargar el archivo `.apk` directamente desde los *Assets* de GitHub.
4.  **Instalación Silenciosa/Asistida:** Utiliza paquetes de Flutter (como `ota_update` o un instalador de paquetes de Android) para iniciar la instalación del nuevo APK de forma nativa sin salir del flujo de trabajo del usuario.

---

## 6. Sincronización y Respaldo (Backup Cloud)
*   **Acción:** Manual o asociada al Cierre de Caja.
*   **Proceso:** Se empaqueta la base de datos Isar actual, se encripta de forma ligera y se transmite a los servidores de Corporación EddamCore a través de una petición segura a la API REST.