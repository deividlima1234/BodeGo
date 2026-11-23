/**
 * =====================================================================
 * BODEGO POS - BACKEND MULTI-TENANT SERVERLESS EN GOOGLE APPS SCRIPT
 * Arquitectura "Spreadsheet per Tenant" con Registro y Recuperación Cloud
 * =====================================================================
 * 
 * Este script maestro administra múltiples bodegas y usuarios de forma 100% aislada:
 * 1. Mantiene una tabla central '_MASTER_ACCOUNTS' para credenciales y mapeo de tiendas.
 * 2. Al registrar un nuevo usuario/negocio, crea automáticamente una Hoja de Cálculo
 *    exclusiva en Google Drive para esa bodega ("BodeGo - [NombreNegocio]").
 * 3. Permite Login / Recuperación de cuenta para usuarios que cambiaron o perdieron su celular.
 * 4. Atiende peticiones de venta, movimientos, catálogo y respaldos abriendo ÚNICAMENTE
 *    la hoja correspondiente al negocio autenticado, garantizando privacidad total.
 */

// Nombre de la hoja maestra de control de cuentas
const MASTER_ACCOUNTS_SHEET = '_MASTER_ACCOUNTS';

// Hojas que se inicializan dentro de la hoja personal de cada bodega
const TENANT_SHEETS = {
  CONFIG: '_CONFIG',
  USUARIOS: 'USUARIOS',
  PRODUCTOS: 'PRODUCTOS',
  CATEGORIAS: 'CATEGORIAS',
  CLIENTES: 'CLIENTES',
  VENTAS_TICKETS: 'VENTAS_TICKETS',
  MOVIMIENTOS_LOG: 'MOVIMIENTOS_LOG',
  DISPOSITIVOS: 'DISPOSITIVOS'
};

/**
 * Endpoint GET: Consultas públicas (ping) o autenticadas por negocio (getCatalog, pullUpdates, getTickets)
 */
function doGet(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(15000);
    const params = e.parameter || {};
    const action = params.action || 'ping';

    // 1. Health check público
    if (action === 'ping') {
      const ssMaster = SpreadsheetApp.getActiveSpreadsheet();
      _ensureMasterSheetInitialized(ssMaster);
      return _jsonResponse({
        success: true,
        message: 'BodeGo Cloud Hub Multi-Tenant activo y listo.',
        serverName: ssMaster.getName(),
        timestamp: new Date().toISOString()
      });
    }

    // 2. Operaciones que requieren autenticación de negocio
    const auth = _authenticateTenant(params.businessId, params.authToken);
    if (!auth.success) {
      return _jsonResponse({ success: false, error: auth.error });
    }

    const tenantSpreadsheet = SpreadsheetApp.openById(auth.account.spreadsheetId);

    if (action === 'getCatalog') {
      const catalog = _exportCatalogFromTenant(tenantSpreadsheet);
      return _jsonResponse({
        success: true,
        businessId: auth.account.businessId,
        businessName: auth.account.businessName,
        data: catalog,
        timestamp: new Date().toISOString()
      });
    }

    if (action === 'pullUpdates') {
      const since = params.since ? new Date(params.since) : new Date(0);
      const updates = _getUpdatesSince(tenantSpreadsheet, since);
      const tickets = _exportTicketsFromTenant(tenantSpreadsheet, 300);
      return _jsonResponse({
        success: true,
        updates: updates,
        tickets: tickets,
        serverTime: new Date().toISOString()
      });
    }

    // ACCIÓN NUEVA: Descarga del Historial de Tickets para sincronización multidispositivo
    if (action === 'getTickets') {
      const tickets = _exportTicketsFromTenant(tenantSpreadsheet, 300);
      return _jsonResponse({
        success: true,
        tickets: tickets,
        serverTime: new Date().toISOString()
      });
    }

    return _jsonResponse({ success: false, error: 'Acción GET no reconocida: ' + action });
  } catch (err) {
    return _jsonResponse({ success: false, error: err.toString() });
  } finally {
    lock.releaseLock();
  }
}

/**
 * Endpoint POST: Registro, Login, Movimientos transaccionales y Respaldos
 */
function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
    if (!e.postData || !e.postData.contents) {
      return _jsonResponse({ success: false, error: 'Cuerpo de la petición vacío' });
    }

    const payload = JSON.parse(e.postData.contents);
    const action = payload.action || 'pushBatch';
    const ssMaster = SpreadsheetApp.getActiveSpreadsheet();
    _ensureMasterSheetInitialized(ssMaster);

    // ========================================================
    // ACCIÓN 1: REGISTRO DE NUEVO NEGOCIO / USUARIO
    // ========================================================
    if (action === 'registerBusiness') {
      const regResult = _registerNewTenant(ssMaster, payload);
      return _jsonResponse(regResult);
    }

    // ========================================================
    // ACCIÓN 2: LOGIN Y RECUPERACIÓN DE NEGOCIO (PÉRDIDA O CAMBIO DE CELULAR)
    // ========================================================
    if (action === 'loginBusiness') {
      const loginResult = _loginTenant(ssMaster, payload);
      return _jsonResponse(loginResult);
    }

    // ========================================================
    // ACCIONES QUE REQUIEREN AUTENTICACIÓN DEL TENANT
    // ========================================================
    const auth = _authenticateTenant(payload.businessId, payload.authToken);
    if (!auth.success) {
      return _jsonResponse({ success: false, error: auth.error });
    }

    const tenantSpreadsheet = SpreadsheetApp.openById(auth.account.spreadsheetId);

    // Guardar Respaldo Completo en la hoja del negocio
    if (action === 'fullBackup') {
      _processTenantFullBackup(tenantSpreadsheet, payload);
      return _jsonResponse({
        success: true,
        businessId: auth.account.businessId,
        message: 'Respaldo completo guardado en tu hoja exclusiva de Google Sheets',
        spreadsheetUrl: tenantSpreadsheet.getUrl(),
        timestamp: new Date().toISOString()
      });
    }

    // Procesar Movimientos de ventas, abonos e ingresos
    if (action === 'pushBatch' || action === 'pushMovement') {
      const results = _processTenantMovements(tenantSpreadsheet, payload);
      return _jsonResponse({
        success: true,
        processed: results.count,
        details: results.details,
        timestamp: new Date().toISOString()
      });
    }

    // ========================================================
    // ACCIÓN 3: ACTUALIZAR PERFIL COMERCIAL (RUC, NOMBRE, CLAVE)
    // ========================================================
    if (action === 'updateBusinessProfile') {
      const updateResult = _updateBusinessProfile(ssMaster, tenantSpreadsheet, auth, payload);
      return _jsonResponse(updateResult);
    }

    // ========================================================
    // ACCIÓN 4: AUTO-PROTEGER HOJAS Y COMPARTIR COMO LECTOR
    // ========================================================
    if (action === 'protectTenantSheets') {
      const protResult = _protectTenantSheets(tenantSpreadsheet, auth.account.ownerEmail);
      return _jsonResponse(protResult);
    }

    return _jsonResponse({ success: false, error: 'Acción POST no reconocida: ' + action });
  } catch (err) {
    return _jsonResponse({ success: false, error: err.toString() });
  } finally {
    lock.releaseLock();
  }
}

// =====================================================================
// FUNCIONES DE CONTROL MULTI-TENANT (REGISTRO, LOGIN Y AUTENTICACIÓN)
// =====================================================================

/**
 * Registra un nuevo negocio y auto-crea su Hoja de Cálculo dedicada en Google Drive
 */
function _registerNewTenant(ssMaster, payload) {
  const masterSheet = ssMaster.getSheetByName(MASTER_ACCOUNTS_SHEET);
  const data = masterSheet.getDataRange().getValues();

  const email = (payload.ownerEmail || '').trim().toLowerCase();
  const password = payload.password || '';
  const businessName = (payload.businessName || 'Mi Bodega').trim();
  const ruc = (payload.ruc || '').trim();
  const ownerName = (payload.ownerName || 'Administrador').trim();

  if (!email || !email.includes('@')) {
    return { success: false, error: 'Correo electrónico inválido' };
  }
  if (!password || password.length < 4) {
    return { success: false, error: 'La contraseña debe tener al menos 4 caracteres' };
  }

  // Verificar si el correo ya está registrado
  for (let i = 1; i < data.length; i++) {
    if (data[i][4] && data[i][4].toString().toLowerCase() === email) {
      return {
        success: false,
        error: 'El correo ' + email + ' ya está registrado en BodeGo. Si perdiste tu celular, inicia sesión para recuperar tu negocio.'
      };
    }
  }

  // 1. Generar IDs únicos
  const timestamp = new Date().getTime();
  const businessId = 'BIZ_' + timestamp + '_' + Math.floor(1000 + Math.random() * 9000);
  const authToken = 'TK_' + Utilities.getUuid().replace(/-/g, '');
  const passwordHash = _hashPassword(password);

  // 2. Crear automáticamente una Hoja de Cálculo exclusiva para este negocio
  const newSheetName = 'BodeGo - ' + businessName;
  const tenantSs = SpreadsheetApp.create(newSheetName);
  const spreadsheetId = tenantSs.getId();

  // Inicializar las 8 pestañas de la tienda en su hoja
  _initializeTenantSheets(tenantSs, {
    businessId: businessId,
    businessName: businessName,
    ruc: ruc,
    ownerEmail: email,
    ownerName: ownerName
  });

  // 3. Registrar el negocio en _MASTER_ACCOUNTS
  masterSheet.appendRow([
    businessId,
    businessName,
    ruc,
    ownerName,
    email,
    passwordHash,
    authToken,
    spreadsheetId,
    new Date().toISOString(), // CreatedAt
    new Date().toISOString(), // LastLoginAt
    'ACTIVE'
  ]);

  return {
    success: true,
    message: '¡Negocio registrado y base de datos aprovisionada exitosamente en Google Drive!',
    businessId: businessId,
    authToken: authToken,
    businessName: businessName,
    ownerEmail: email,
    spreadsheetId: spreadsheetId,
    spreadsheetUrl: tenantSs.getUrl()
  };
}

/**
 * Autentica al usuario por Email y Contraseña (Login para recuperación tras pérdida de teléfono)
 */
function _loginTenant(ssMaster, payload) {
  const masterSheet = ssMaster.getSheetByName(MASTER_ACCOUNTS_SHEET);
  const data = masterSheet.getDataRange().getValues();

  const email = (payload.email || '').trim().toLowerCase();
  const password = payload.password || '';
  const passwordHash = _hashPassword(password);

  if (!email || !password) {
    return { success: false, error: 'Ingresa correo y contraseña' };
  }

  for (let i = 1; i < data.length; i++) {
    const rowEmail = (data[i][4] || '').toString().toLowerCase();
    const rowPassHash = data[i][5] || '';
    const status = data[i][10] || 'ACTIVE';

    if (rowEmail === email) {
      if (rowPassHash !== passwordHash) {
        return { success: false, error: 'Contraseña incorrecta' };
      }
      if (status !== 'ACTIVE') {
        return { success: false, error: 'Esta cuenta se encuentra inactiva o suspendida' };
      }

      // Actualizar último login y renovar token si es necesario
      const businessId = data[i][0];
      const businessName = data[i][1];
      const ruc = data[i][2];
      const ownerName = data[i][3];
      const authToken = data[i][6];
      const spreadsheetId = data[i][7];

      masterSheet.getRange(i + 1, 10).setValue(new Date().toISOString());

      // Abrir su hoja para obtener snapshot completo de recuperación (incluyendo tickets)
      let catalog = { products: [], customers: [], categories: [], users: [], tickets: [] };
      try {
        const tenantSs = SpreadsheetApp.openById(spreadsheetId);
        catalog = _exportCatalogFromTenant(tenantSs);
      } catch (e) {
        // En caso de error de lectura de hoja
      }

      return {
        success: true,
        message: '¡Bienvenido de vuelta a BodeGo! Catálogo recuperado con éxito.',
        businessId: businessId,
        authToken: authToken,
        businessName: businessName,
        ruc: ruc,
        ownerName: ownerName,
        ownerEmail: email,
        spreadsheetId: spreadsheetId,
        catalog: catalog
      };
    }
  }

  return { success: false, error: 'No existe ninguna cuenta registrada con el correo ' + email };
}

/**
 * Valida que el businessId y authToken pertenezcan a un negocio activo
 */
function _authenticateTenant(businessId, authToken) {
  if (!businessId || !authToken) {
    return { success: false, error: 'Acceso no autorizado: se requiere businessId y authToken' };
  }

  const ssMaster = SpreadsheetApp.getActiveSpreadsheet();
  const masterSheet = ssMaster.getSheetByName(MASTER_ACCOUNTS_SHEET);
  const data = masterSheet.getDataRange().getValues();

  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === businessId && data[i][6] === authToken) {
      if (data[i][10] !== 'ACTIVE') {
        return { success: false, error: 'Cuenta suspendida o inactiva' };
      }
      return {
        success: true,
        rowIndex: i + 1,
        account: {
          businessId: data[i][0],
          businessName: data[i][1],
          ruc: data[i][2],
          ownerName: data[i][3],
          ownerEmail: data[i][4],
          spreadsheetId: data[i][7]
        }
      };
    }
  }

  return { success: false, error: 'Credenciales inválidas o negocio no registrado en el sistema' };
}

/**
 * Actualiza el perfil comercial (RUC, nombre de negocio, contraseña) firmado con Token
 */
function _updateBusinessProfile(ssMaster, tenantSs, auth, payload) {
  const masterSheet = ssMaster.getSheetByName(MASTER_ACCOUNTS_SHEET);
  const row = auth.rowIndex;
  const updates = payload.data || payload;

  const newBusinessName = (updates.businessName || '').toString().trim();
  const newRuc = (updates.ruc != null) ? updates.ruc.toString().trim() : '';
  const newOwnerName = (updates.ownerName || '').toString().trim();
  const newPassword = (updates.newPassword || '').toString().trim();

  // 1. Actualizar en _MASTER_ACCOUNTS
  if (row && row > 1) {
    if (newBusinessName) masterSheet.getRange(row, 2).setValue(newBusinessName);
    if (newRuc !== '') masterSheet.getRange(row, 3).setValue(newRuc);
    if (newOwnerName) masterSheet.getRange(row, 4).setValue(newOwnerName);
    if (newPassword && newPassword.length >= 4) {
      masterSheet.getRange(row, 6).setValue(_hashPassword(newPassword));
    }
    masterSheet.getRange(row, 10).setValue(new Date().toISOString());
  }

  // 2. Actualizar en la pestaña _CONFIG de la hoja privada
  const configSheet = tenantSs.getSheetByName(TENANT_SHEETS.CONFIG);
  if (configSheet) {
    const cData = configSheet.getDataRange().getValues();
    const map = {};
    for (let i = 1; i < cData.length; i++) {
      map[cData[i][0]] = i + 1;
    }

    if (newBusinessName) {
      if (map['businessName']) configSheet.getRange(map['businessName'], 2).setValue(newBusinessName);
      else configSheet.appendRow(['businessName', newBusinessName, new Date().toISOString()]);
      try { tenantSs.rename('BodeGo - ' + newBusinessName); } catch (_) {}
    }

    if (newRuc !== '') {
      if (map['ruc']) configSheet.getRange(map['ruc'], 2).setValue(newRuc);
      else configSheet.appendRow(['ruc', newRuc, new Date().toISOString()]);
    }

    if (newOwnerName) {
      if (map['ownerName']) configSheet.getRange(map['ownerName'], 2).setValue(newOwnerName);
      else configSheet.appendRow(['ownerName', newOwnerName, new Date().toISOString()]);
    }

    if (updates.phone) {
      if (map['phone']) configSheet.getRange(map['phone'], 2).setValue(updates.phone);
      else configSheet.appendRow(['phone', updates.phone, new Date().toISOString()]);
    }

    if (updates.address) {
      if (map['address']) configSheet.getRange(map['address'], 2).setValue(updates.address);
      else configSheet.appendRow(['address', updates.address, new Date().toISOString()]);
    }
  }

  return {
    success: true,
    message: 'Perfil comercial actualizado con éxito en la nube.',
    businessName: newBusinessName || auth.account.businessName,
    ruc: newRuc !== '' ? newRuc : auth.account.ruc,
    timestamp: new Date().toISOString()
  };
}

/**
 * Aplica protección contra edición manual y comparte en modo Lector (Viewer)
 */
function _protectTenantSheets(tenantSs, ownerEmail) {
  const sheets = tenantSs.getSheets();
  for (let i = 0; i < sheets.length; i++) {
    const sheet = sheets[i];
    try {
      const protections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
      if (protections.length === 0) {
        const prot = sheet.protect().setDescription('BodeGo POS - Solo Lectura');
        prot.setWarningOnly(true);
      }
    } catch (_) {}
  }

  if (ownerEmail && ownerEmail.includes('@')) {
    try {
      tenantSs.addViewer(ownerEmail);
    } catch (_) {}
  }

  return { success: true, message: 'Hojas protegidas en modo solo lectura para navegador' };
}

// =====================================================================
// OPERACIONES EN LA HOJA EXCLUSIVA DEL NEGOCIO (ISOLATED TENANT SHEET)
// =====================================================================

function _processTenantMovements(tenantSs, payload) {
  const logSheet = tenantSs.getSheetByName(TENANT_SHEETS.MOVIMIENTOS_LOG);
  const ticketsSheet = tenantSs.getSheetByName(TENANT_SHEETS.VENTAS_TICKETS);
  const productsSheet = tenantSs.getSheetByName(TENANT_SHEETS.PRODUCTOS);
  const customersSheet = tenantSs.getSheetByName(TENANT_SHEETS.CLIENTES);
  const devicesSheet = tenantSs.getSheetByName(TENANT_SHEETS.DISPOSITIVOS);

  const movements = payload.movements || [payload];
  let processedCount = 0;

  if (payload.deviceInfo) {
    _upsertDevice(devicesSheet, payload.deviceInfo);
  }

  for (let i = 0; i < movements.length; i++) {
    const mov = movements[i];
    const movId = mov.id || ('MOV_' + new Date().getTime() + '_' + i);
    const timestamp = mov.timestamp || new Date().toISOString();
    const type = mov.type || 'DESCONOCIDO';
    const deviceId = mov.deviceId || 'DEV_UNKNOWN';
    const detail = mov.detail || '';
    const data = mov.data || {};

    // 1. Agregar a MOVIMIENTOS_LOG
    logSheet.appendRow([
      movId,
      timestamp,
      deviceId,
      type,
      detail,
      JSON.stringify(data)
    ]);

    // 2. Procesar según tipo de movimiento
    if (type === 'VENTA') {
      const ticket = data.ticket || data;
      ticketsSheet.appendRow([
        ticket.id,
        ticket.ticketNumber,
        ticket.date || timestamp,
        ticket.subtotal || 0,
        ticket.discount || 0,
        ticket.total || 0,
        ticket.isCredit ? 'CREDITO_FIADO' : 'CONTADO',
        ticket.customerName || '',
        ticket.cashierName || '',
        JSON.stringify(ticket.items || []),
        deviceId,
        new Date().toISOString()
      ]);

      if (ticket.items && Array.isArray(ticket.items)) {
        for (let j = 0; j < ticket.items.length; j++) {
          const item = ticket.items[j];
          _adjustProductStock(productsSheet, item.name, item.productId, -Number(item.quantity || 0));
        }
      }

      if (ticket.isCredit && (ticket.customerId || ticket.customerName)) {
        _adjustCustomerDebt(customersSheet, ticket.customerId, ticket.customerName, Number(ticket.total || 0));
      }
    } else if (type === 'ABONO_DEUDA') {
      _adjustCustomerDebt(customersSheet, data.customerId, data.customerName, -Number(data.amount || 0));
    } else if (type === 'REPOSICION_STOCK') {
      _adjustProductStock(productsSheet, data.productName, data.productId, Number(data.quantity || 0), data.newCostPrice);
    }

    processedCount++;
  }

  return { count: processedCount, details: 'Movimientos registrados en la hoja exclusiva de la bodega' };
}

function _processTenantFullBackup(tenantSs, payload) {
  const data = payload.data || payload;

  if (data.businessConfig) {
    const configSheet = tenantSs.getSheetByName(TENANT_SHEETS.CONFIG);
    configSheet.clearContents();
    configSheet.appendRow(['Clave', 'Valor', 'Ultima_Actualizacion']);
    const conf = data.businessConfig;
    for (const k in conf) {
      configSheet.appendRow([k, conf[k], new Date().toISOString()]);
    }
  }

  if (data.categories && Array.isArray(data.categories)) {
    const catSheet = tenantSs.getSheetByName(TENANT_SHEETS.CATEGORIAS);
    catSheet.clearContents();
    catSheet.appendRow(['ID_Categoria', 'Nombre', 'Color_Hex', 'Actualizado_En']);
    data.categories.forEach((c, idx) => {
      catSheet.appendRow([c.id || (idx + 1), c.name, c.hexColor || '#4353FF', new Date().toISOString()]);
    });
  }

  if (data.products && Array.isArray(data.products)) {
    const prodSheet = tenantSs.getSheetByName(TENANT_SHEETS.PRODUCTOS);
    prodSheet.clearContents();
    prodSheet.appendRow([
      'ID_Producto', 'Codigo_Barras', 'Nombre', 'Categoria',
      'Precio_Costo', 'Precio_Venta', 'Stock_Actual', 'Stock_Minimo',
      'Unidad', 'Actualizado_En'
    ]);
    data.products.forEach((p, idx) => {
      prodSheet.appendRow([
        p.id || (idx + 1),
        p.barcode || '',
        p.name || '',
        p.categoryName || '',
        p.costPrice || 0,
        p.salePrice || 0,
        p.stock || 0,
        p.minStock || 5,
        p.unit || 'und',
        new Date().toISOString()
      ]);
    });
  }

  if (data.customers && Array.isArray(data.customers)) {
    const custSheet = tenantSs.getSheetByName(TENANT_SHEETS.CLIENTES);
    custSheet.clearContents();
    custSheet.appendRow([
      'ID_Cliente', 'Nombre', 'Telefono', 'Direccion',
      'Limite_Credito', 'Deuda_Actual', 'Actualizado_En'
    ]);
    data.customers.forEach((c, idx) => {
      custSheet.appendRow([
        c.id || (idx + 1),
        c.name || '',
        c.phone || '',
        c.address || '',
        c.creditLimit || 100,
        c.currentDebt || 0,
        new Date().toISOString()
      ]);
    });
  }

  if (data.users && Array.isArray(data.users)) {
    let userSheet = tenantSs.getSheetByName(TENANT_SHEETS.USUARIOS);
    if (!userSheet) {
      userSheet = tenantSs.insertSheet(TENANT_SHEETS.USUARIOS);
      try {
        const prot = userSheet.protect().setDescription('BodeGo POS - Base de Datos Sincronizada');
        prot.setWarningOnly(true);
      } catch (_) {}
    }
    userSheet.clearContents();
    userSheet.appendRow([
      'ID_Usuario', 'Nombre', 'Rol', 'PIN_Encriptado',
      'Email', 'Estado', 'Actualizado_En'
    ]);
    data.users.forEach((u, idx) => {
      userSheet.appendRow([
        u.id || (idx + 1),
        u.name || '',
        u.role || 'cajero',
        u.pin || '',
        u.email || '',
        u.status || 'ACTIVO',
        new Date().toISOString()
      ]);
    });
  }
}

function _exportCatalogFromTenant(tenantSs) {
  const prodSheet = tenantSs.getSheetByName(TENANT_SHEETS.PRODUCTOS);
  const custSheet = tenantSs.getSheetByName(TENANT_SHEETS.CLIENTES);
  const catSheet = tenantSs.getSheetByName(TENANT_SHEETS.CATEGORIAS);
  const userSheet = tenantSs.getSheetByName(TENANT_SHEETS.USUARIOS);

  const products = [];
  if (prodSheet) {
    const pRows = prodSheet.getDataRange().getValues();
    for (let i = 1; i < pRows.length; i++) {
      if (!pRows[i][2]) continue;
      products.push({
        id: pRows[i][0],
        barcode: pRows[i][1],
        name: pRows[i][2],
        categoryName: pRows[i][3],
        costPrice: Number(pRows[i][4]) || 0,
        salePrice: Number(pRows[i][5]) || 0,
        stock: Number(pRows[i][6]) || 0,
        minStock: Number(pRows[i][7]) || 5,
        unit: pRows[i][8] || 'und'
      });
    }
  }

  const customers = [];
  if (custSheet) {
    const cRows = custSheet.getDataRange().getValues();
    for (let i = 1; i < cRows.length; i++) {
      if (!cRows[i][1]) continue;
      customers.push({
        id: cRows[i][0],
        name: cRows[i][1],
        phone: cRows[i][2],
        address: cRows[i][3],
        creditLimit: Number(cRows[i][4]) || 100,
        currentDebt: Number(cRows[i][5]) || 0
      });
    }
  }

  const categories = [];
  if (catSheet) {
    const kRows = catSheet.getDataRange().getValues();
    for (let i = 1; i < kRows.length; i++) {
      if (!kRows[i][1]) continue;
      categories.push({
        id: kRows[i][0],
        name: kRows[i][1],
        hexColor: kRows[i][2] || '#4353FF'
      });
    }
  }

  const users = [];
  if (userSheet) {
    const uRows = userSheet.getDataRange().getValues();
    for (let i = 1; i < uRows.length; i++) {
      if (!uRows[i][1]) continue;
      users.push({
        id: uRows[i][0],
        name: uRows[i][1],
        role: uRows[i][2] || 'cajero',
        pin: uRows[i][3] || '',
        email: uRows[i][4] || '',
        status: uRows[i][5] || 'ACTIVO'
      });
    }
  }

  // NUEVO: Exportar también el historial de tickets para hidratación inmediata
  const tickets = _exportTicketsFromTenant(tenantSs, 300);

  return {
    products: products,
    customers: customers,
    categories: categories,
    users: users,
    tickets: tickets
  };
}

/**
 * NUEVA FUNCIÓN: Lee y formatea los tickets de la pestaña VENTAS_TICKETS del negocio
 */
function _exportTicketsFromTenant(tenantSs, limit) {
  limit = limit || 300;
  const sheet = tenantSs.getSheetByName(TENANT_SHEETS.VENTAS_TICKETS);
  if (!sheet) return [];

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return [];

  const startRow = Math.max(2, lastRow - limit + 1);
  const numRows = lastRow - startRow + 1;
  const values = sheet.getRange(startRow, 1, numRows, 12).getValues();

  const tickets = [];
  for (let i = values.length - 1; i >= 0; i--) {
    const r = values[i];
    const idTicket = String(r[0] || '').trim();
    if (!idTicket) continue;

    let items = [];
    try {
      if (r[9]) {
        items = typeof r[9] === 'string' ? JSON.parse(r[9]) : r[9];
      }
    } catch (e) {
      items = [];
    }

    const tipoPago = String(r[6] || '').toUpperCase();
    const isCredit = tipoPago.indexOf('FIAD') !== -1 || tipoPago.indexOf('CREDIT') !== -1;
    const dateVal = r[2];
    const dateIso = (dateVal instanceof Date) ? dateVal.toISOString() : String(dateVal || '');

    tickets.push({
      id: idTicket,
      ticketNumber: String(r[1] || 'TKT-0000'),
      date: dateIso,
      subtotal: Number(r[3]) || 0,
      discount: Number(r[4]) || 0,
      total: Number(r[5]) || 0,
      isCredit: isCredit,
      customerName: String(r[7] || ''),
      cashierName: String(r[8] || 'Cajero'),
      businessName: tenantSs.getName().replace('BodeGo - ', '').trim(),
      items: items,
      isSynced: true
    });
  }
  return tickets;
}

function _getUpdatesSince(tenantSs, sinceDate) {
  const logSheet = tenantSs.getSheetByName(TENANT_SHEETS.MOVIMIENTOS_LOG);
  if (!logSheet) return [];
  const rows = logSheet.getDataRange().getValues();
  const updates = [];

  for (let i = 1; i < rows.length; i++) {
    const rowDate = new Date(rows[i][1]);
    if (rowDate > sinceDate) {
      updates.push({
        id: rows[i][0],
        timestamp: rows[i][1],
        deviceId: rows[i][2],
        type: rows[i][3],
        detail: rows[i][4],
        data: rows[i][5] ? JSON.parse(rows[i][5]) : {}
      });
    }
  }
  return updates;
}

function _adjustProductStock(sheet, name, id, delta, newCost) {
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return;

  for (let r = 1; r < data.length; r++) {
    const rowName = data[r][2];
    const rowId = data[r][0];
    if ((name && rowName && rowName.toString().toLowerCase() === name.toString().toLowerCase()) ||
        (id && rowId && rowId.toString() === id.toString())) {
      const currentStock = Number(data[r][6]) || 0;
      const newStock = Math.max(0, currentStock + delta);
      sheet.getRange(r + 1, 7).setValue(newStock);
      sheet.getRange(r + 1, 10).setValue(new Date().toISOString());
      if (newCost && Number(newCost) > 0) {
        sheet.getRange(r + 1, 5).setValue(Number(newCost));
      }
      break;
    }
  }
}

function _adjustCustomerDebt(sheet, id, name, delta) {
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return;

  for (let r = 1; r < data.length; r++) {
    const rowId = data[r][0];
    const rowName = data[r][1];
    if ((id && rowId && rowId.toString() === id.toString()) ||
        (name && rowName && rowName.toString().toLowerCase() === name.toString().toLowerCase())) {
      const currentDebt = Number(data[r][5]) || 0;
      const newDebt = Math.max(0, currentDebt + delta);
      sheet.getRange(r + 1, 6).setValue(newDebt);
      sheet.getRange(r + 1, 7).setValue(new Date().toISOString());
      break;
    }
  }
}

function _upsertDevice(sheet, dev) {
  if (!sheet) return;
  const data = sheet.getDataRange().getValues();
  let found = false;
  for (let i = 1; i < data.length; i++) {
    if (data[i][0] === dev.machineId) {
      sheet.getRange(i + 1, 2).setValue(dev.name || data[i][1]);
      sheet.getRange(i + 1, 3).setValue(dev.role || data[i][2]);
      sheet.getRange(i + 1, 5).setValue(new Date().toISOString());
      found = true;
      break;
    }
  }
  if (!found) {
    sheet.appendRow([
      dev.machineId,
      dev.name || 'Terminal BodeGo',
      dev.role || 'secondary',
      new Date().toISOString(),
      new Date().toISOString()
    ]);
  }
}

function _initializeTenantSheets(tenantSs, info) {
  for (const key in TENANT_SHEETS) {
    const name = TENANT_SHEETS[key];
    let sheet = tenantSs.getSheetByName(name);
    if (!sheet) {
      sheet = tenantSs.insertSheet(name);
    }
    sheet.clearContents();

    if (name === TENANT_SHEETS.CONFIG) {
      sheet.appendRow(['Clave', 'Valor', 'Ultima_Actualizacion']);
      sheet.appendRow(['businessId', info.businessId, new Date().toISOString()]);
      sheet.appendRow(['businessName', info.businessName, new Date().toISOString()]);
      sheet.appendRow(['ruc', info.ruc, new Date().toISOString()]);
      sheet.appendRow(['ownerEmail', info.ownerEmail, new Date().toISOString()]);
    } else if (name === TENANT_SHEETS.USUARIOS) {
      sheet.appendRow(['ID_Usuario', 'Nombre', 'Rol', 'PIN_Encriptado', 'Email', 'Estado', 'Actualizado_En']);
    } else if (name === TENANT_SHEETS.PRODUCTOS) {
      sheet.appendRow(['ID_Producto', 'Codigo_Barras', 'Nombre', 'Categoria', 'Precio_Costo', 'Precio_Venta', 'Stock_Actual', 'Stock_Minimo', 'Unidad', 'Actualizado_En']);
    } else if (name === TENANT_SHEETS.CATEGORIAS) {
      sheet.appendRow(['ID_Categoria', 'Nombre', 'Color_Hex', 'Actualizado_En']);
    } else if (name === TENANT_SHEETS.CLIENTES) {
      sheet.appendRow(['ID_Cliente', 'Nombre', 'Telefono', 'Direccion', 'Limite_Credito', 'Deuda_Actual', 'Actualizado_En']);
    } else if (name === TENANT_SHEETS.VENTAS_TICKETS) {
      sheet.appendRow(['ID_Ticket', 'Numero', 'Fecha_Hora', 'Subtotal', 'Descuento', 'Total', 'Tipo_Pago', 'Cliente', 'Cajero', 'Items_JSON', 'ID_Dispositivo', 'Sincronizado_En']);
    } else if (name === TENANT_SHEETS.MOVIMIENTOS_LOG) {
      sheet.appendRow(['ID_Movimiento', 'Timestamp', 'ID_Dispositivo', 'Tipo_Movimiento', 'Detalle', 'Payload_JSON']);
    } else if (name === TENANT_SHEETS.DISPOSITIVOS) {
      sheet.appendRow(['ID_Maquina', 'Nombre_Equipo', 'Rol', 'Fecha_Registro', 'Ultima_Actividad']);
    }

    // Proteger cada hoja en modo solo lectura para navegador
    try {
      const prot = sheet.protect().setDescription('BodeGo POS - Base de Datos Sincronizada');
      prot.setWarningOnly(true);
    } catch (_) {}
  }

  // Eliminar la "Hoja 1" por defecto si existe
  const defaultSheet = tenantSs.getSheetByName('Hoja 1') || tenantSs.getSheetByName('Sheet1');
  if (defaultSheet && tenantSs.getSheets().length > 1) {
    try {
      tenantSs.deleteSheet(defaultSheet);
    } catch (_) {}
  }

  // Compartir la hoja con el correo del dueño en modo LECTOR (Viewer)
  if (info.ownerEmail && info.ownerEmail.includes('@')) {
    try {
      tenantSs.addViewer(info.ownerEmail);
    } catch (err) {
      Logger.log('Nota auto-viewer: ' + err);
    }
  }
}

function _ensureMasterSheetInitialized(ssMaster) {
  let sheet = ssMaster.getSheetByName(MASTER_ACCOUNTS_SHEET);
  if (!sheet) {
    sheet = ssMaster.insertSheet(MASTER_ACCOUNTS_SHEET, 0);
    sheet.appendRow([
      'business_id',
      'business_name',
      'ruc',
      'owner_name',
      'owner_email',
      'password_hash',
      'auth_token',
      'spreadsheet_id',
      'created_at',
      'last_login_at',
      'status'
    ]);

    try {
      const masterProt = sheet.protect().setDescription('BodeGo Master Accounts - Directorio Central');
      masterProt.setWarningOnly(true);
    } catch (_) {}
  }
}

function _hashPassword(password) {
  const rawBytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, password, Utilities.Charset.UTF_8);
  let hash = '';
  for (let i = 0; i < rawBytes.length; i++) {
    const byteVal = (rawBytes[i] < 0 ? rawBytes[i] + 256 : rawBytes[i]).toString(16);
    hash += (byteVal.length === 1 ? '0' : '') + byteVal;
  }
  return hash;
}

function _jsonResponse(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

