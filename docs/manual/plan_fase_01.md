# Plan de Desarrollo y QA - FASE 01: Onboarding, Autenticación y Entrada a Caja

## 1. Alcance de la Fase 01
Esta fase cubre el ciclo de vida completo desde el **primer arranque de la aplicación (instalación en limpio)** pasando por la presentación institucional, tour educativo, modales de contingencia/nube, asistente de configuración inicial del negocio, pantalla de desbloqueo diario por PIN, hasta culminar en la **ventana principal de Caja y Venta**.

---

## 2. Inventario Detallado de Pantallas y Capturas (15 Vistas)

| # | Archivo PNG | Widget Principal | Tipo de Pantalla | Descripción para el Usuario Final |
|---|---|---|---|---|
| **01** | `01_01_splash_arranque.png` | `SplashScreen` | Cinemática | Pantalla de inicio animada con el isotipo de BodeGo, versión y firma de EddamCore. |
| **02** | `01_02_bienvenida_oficial.png` | `WelcomePresentationView` | Pantalla Completa | Ventana institucional de bienvenida: insignia POS Oficial, isotipo central y accesos de configuración. |
| **03** | `01_03_modal_login_nube.png` | `CloudLoginModal` | BottomSheet Modal | Diálogo para restaurar bodega existente mediante correo y contraseña vinculados a Google Drive / Sheets. |
| **04** | `01_04_modal_vincular_secundario.png` | `SecondaryDeviceOnboardingModal` | BottomSheet Modal | Asistente de emparejamiento para conectar el celular como terminal secundaria o lector móvil mediante red local / QR. |
| **05** | `01_05_modal_terminos_legales.png` | `LegalTermsModal` | BottomSheet Modal | Términos del servicio, política de privacidad offline-first y garantía corporativa. |
| **06** | `01_06_tour_slide1_ventas.png` | `OnboardingScreen` (Tour Slide 1) | Carrusel Interactivo | Diapositiva educativa: *Ventas y Catálogo al Instante* con ilustración de escáner láser y carrito. |
| **07** | `01_07_tour_slide2_fiados.png` | `OnboardingScreen` (Tour Slide 2) | Carrusel Interactivo | Diapositiva educativa: *Control de Fiados sin Enredos* con libreta de caseros y alertas de límite. |
| **08** | `01_08_tour_slide3_impresoras.png` | `OnboardingScreen` (Tour Slide 3) | Carrusel Interactivo | Diapositiva educativa: *Tickets Térmicos Bluetooth* con emisión de boletas en 58/80mm. |
| **09** | `01_09_tour_slide4_cierre_z.png` | `OnboardingScreen` (Tour Slide 4) | Carrusel Interactivo | Diapositiva educativa: *Caja Cuadrada y Cierre Z* con balance al centavo y botón 'Empezar Configuración'. |
| **10** | `01_10_wizard_paso1_negocio.png` | `OnboardingScreen` (Paso 1) | Formulario Wizard | Configuración de identidad: Nombre de la Bodega, RUC, Dirección y selector visual de logotipo. |
| **11** | `01_11_wizard_paso2_administrador.png` | `OnboardingScreen` (Paso 2) | Formulario Wizard | Registro del dueño/administrador: Nombre, Correo electrónico y Contraseña maestra. |
| **12** | `01_12_wizard_paso3_cajero_pin.png` | `OnboardingScreen` (Paso 3) | Formulario Wizard | Asignación del cajero de turno: Nombre ("Carlos Mendoza"), teclado numérico y creación de PIN de 4 dígitos. |
| **13** | `01_13_login_pin_pantalla_bloqueo.png` | `PinLoginScreen` | Pantalla de Acceso | Terminal bloqueada en espera de PIN para abrir turno, mostrando nombre del negocio y teclado táctil. |
| **14** | `01_14_login_pin_ingresando.png` | `PinLoginScreen` | Pantalla de Acceso | Teclado numérico con 3 dígitos ingresados (esferas de seguridad rellenas) simulando digitación en vivo. |
| **15** | `01_15_caja_principal_llegada.png` | `MainPosScreen` | Dashboard POS | Entrada a la terminal de ventas activa: catálogo cargado, barra de búsqueda, categorías y carrito listo en S/ 0.00. |

---

## 3. Guía de Interacciones y Estado Simulado por Pantalla

### Captura 01: Splash Screen (`01_01_splash_arranque.png`)
* **Widget:** `SplashScreen`
* **Interacción:** Renderizado en `Duration(milliseconds: 1000)` para capturar el logo estabilizado y el badge inferior visible.
* **Callouts para el manual:**
  - `[A]` Isotipo oficial de BodeGo con efecto de elevación.
  - `[B]` Título y eslogan de la versión.

### Captura 02: Bienvenida Oficial (`01_02_bienvenida_oficial.png`)
* **Widget:** `WelcomePresentationView`
* **Interacción:** `tester.pumpAndSettle()`.
* **Callouts para el manual:**
  - `[A]` Badge de POS Oficial.
  - `[B]` Botón "Iniciar Sesión" (para usuarios recurrentes con backup en nube).
  - `[C]` Badge de emparejamiento para dispositivos secundarios.
  - `[D]` Botón "Ver Novedades y Guía Rápida" (abre el tour).
  - `[E]` Botón "Configurar mi Bodega" (acceso directo al asistente).

### Captura 03: Modal de Inicio de Sesión en la Nube (`01_03_modal_login_nube.png`)
* **Widget:** Despliegue de `CloudLoginModal.show(context)`
* **Interacción:** Inyección de texto simulado:
  - Correo: `donlucho@bodegadonlucho.pe`
  - Contraseña: `••••••••`
* **Callouts para el manual:**
  - `[A]` Campo de Correo del Administrador.
  - `[B]` Contraseña de respaldo.
  - `[C]` Botón "Restaurar Negocio y Productos".

### Captura 04: Modal Vincular Dispositivo Secundario (`01_04_modal_vincular_secundario.png`)
* **Widget:** Despliegue de `SecondaryDeviceOnboardingModal.show(context)`
* **Interacción:** Renderizado del Paso 0 (Instrucciones de red Wi-Fi compartida y búsqueda de terminal maestra).
* **Callouts para el manual:**
  - `[A]` Indicador de estado de red local.
  - `[B]` Botón para escanear código QR de la caja principal.
  - `[C]` Opción de sincronización manual por IP.

### Captura 05: Modal Términos y Condiciones Legales (`01_05_modal_terminos_legales.png`)
* **Widget:** Despliegue de `LegalTermsModal.show(context)`
* **Interacción:** Pestaña 0 ("Condiciones") activa con scroll superior.
* **Callouts para el manual:**
  - `[A]` Selector de pestañas: Condiciones, Privacidad y Garantía.
  - `[B]` Respaldo institucional de Corporación EddamCore.

### Capturas 06 a 09: Tour Interactivo (Slides 1 al 4)
* **Widget:** `OnboardingScreen` con `_currentPhase = OnboardingPhase.tour`.
* **Interacciones:** Avance de slide mediante `_tourPageController.animateToPage(index)`.
  - **Slide 1:** Ilustración animada de carrito con rayo láser y beneficios de escaneo.
  - **Slide 2:** Ilustración de libreta de fiados y beneficios de créditos.
  - **Slide 3:** Ilustración de impresora térmica y boleta física.
  - **Slide 4:** Ilustración de gaveta de dinero y botón verde destacado "Empezar Configuración".

### Capturas 10 a 12: Asistente de Configuración (Wizard)
* **Widget:** `OnboardingScreen` con `_currentPhase = OnboardingPhase.form`.
* **Interacciones:**
  - **Paso 1 (Negocio):** Llenar campos:
    - Nombre: `Minimarket Doruck`
    - RUC: `20601234567`
    - Dirección: `Av. Principal 123`
    - Preset seleccionado: `storefront`
  - **Paso 2 (Administrador):**
    - Dueño: `Devid`
    - Correo: `admin@minimakt.com`
    - Contraseña: `••••••••`
  - **Paso 3 (Cajero y PIN):**
    - Nombre Cajero: `Eloy`
    - Teclado PIN: Tipeo de `1`, `2`, `3`, `4` mostrando los 4 puntos activos y botón "Finalizar y Abrir Caja".

### Capturas 13 y 14: Acceso Diario por PIN (`PinLoginScreen`)
* **Widget:** `PinLoginScreen` con la base de datos ya inicializada con "Minimarket Doruck".
* **Interacciones:**
  - **Captura 13:** Estado inicial con teclado numérico limpio y saludo.
  - **Captura 14:** Tipeo de 3 números con 3 círculos rellenos.

### Captura 15: Llegada a la Ventana Principal "Caja & Venta" (`MainPosScreen`)
* **Widget:** `MainPosScreen` con `PosModuleScreen` en índice 0.
* **Datos Visibles:**
  - Barra superior: `Minimarket Doruck` | `Cajero: Eloy`.
  - Categorías visibles: `Todos`, `Abarrotes`, `Lácteos y Huevos`, `Bebidas`, `Snacks`, `Limpieza`.
  - Cuadrícula con productos cargados (Arroz Costeño, Aceite Primor, Leche Gloria, etc.).
  - Carrito flotante en estado listo: `0 productos | S/ 0.00`.

