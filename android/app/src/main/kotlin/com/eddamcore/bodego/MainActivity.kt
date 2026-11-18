package com.eddamcore.bodego

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.print.PrintAttributes
import android.print.PrintManager
import android.provider.Settings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val OTA_CHANNEL = "com.eddamcore.bodego/ota_updater"
    private val SOUND_CHANNEL = "com.eddamcore.bodego/sound"
    private val NATIVE_PRINTER_CHANNEL = "com.eddamcore.bodego/native_printer"
    private val BLUETOOTH_CHANNEL = "com.eddamcore.bodego/bluetooth_pos"
    private val USB_CHANNEL = "com.eddamcore.bodego/usb_pos"

    private var toneGenerator: ToneGenerator? = null
    private var discoveryReceiver: BroadcastReceiver? = null
    private val discoveredDevicesList = mutableListOf<Map<String, Any>>()

    private fun getBluetoothAdapter(): BluetoothAdapter? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bm?.adapter ?: BluetoothAdapter.getDefaultAdapter()
        } else {
            @Suppress("DEPRECATION")
            BluetoothAdapter.getDefaultAdapter()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Canal nativo para efectos de sonido ultra-rápidos (0ms latencia)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playScannerBeep" -> {
                    try {
                        if (toneGenerator == null) {
                            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                        }
                        toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 110)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 110)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("SOUND_ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "playErrorBeep" -> {
                    try {
                        if (toneGenerator == null) {
                            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                        }
                        toneGenerator?.startTone(ToneGenerator.TONE_PROP_NACK, 250)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SOUND_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. Canal nativo para actualización OTA de la APK
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                        val versionName = pInfo.versionName ?: "1.0.0"
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "versionName" to versionName,
                                "versionCode" to versionCode
                            )
                        )
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "La ruta del APK no puede estar vacía", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "El archivo APK no existe en $filePath", null)
                            return@setMethodCallHandler
                        }

                        val uri: Uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. Canal nativo para Servicio de Impresión Android (Epson, HP, Canon, A4 y Media Hoja)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_PRINTER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "printHtml" -> {
                    val htmlContent = call.argument<String>("html")
                    val jobName = call.argument<String>("jobName") ?: "Ticket_BodeGo"
                    val paperFormat = call.argument<String>("paperFormat") ?: "half_a4_vertical"

                    if (htmlContent.isNullOrEmpty()) {
                        result.error("EMPTY_HTML", "El contenido HTML está vacío", null)
                        return@setMethodCallHandler
                    }

                    try {
                        runOnUiThread {
                            val webView = WebView(this)
                            webView.webViewClient = object : WebViewClient() {
                                override fun onPageFinished(view: WebView?, url: String?) {
                                    super.onPageFinished(view, url)
                                    val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
                                    if (printManager == null) {
                                        result.error("NO_PRINT_SERVICE", "Servicio de impresión no disponible en este dispositivo", null)
                                        return
                                    }

                                    val printAdapter = webView.createPrintDocumentAdapter(jobName)
                                    val attributesBuilder = PrintAttributes.Builder()

                                    if (paperFormat == "half_a4_vertical") {
                                        // Media hoja A4 vertical: 105 mm x 297 mm (4134 x 11693 mils)
                                        val halfA4Size = PrintAttributes.MediaSize(
                                            "MEDIA_HOJA_A4_V",
                                            "Media Hoja A4 (105x297mm)",
                                            4134,
                                            11693
                                        )
                                        attributesBuilder.setMediaSize(halfA4Size)
                                    } else if (paperFormat == "strip_80mm") {
                                        // Tira de 80 mm x 297 mm (3150 x 11693 mils)
                                        val strip80Size = PrintAttributes.MediaSize(
                                            "TIRA_80MM",
                                            "Tira 80mm",
                                            3150,
                                            11693
                                        )
                                        attributesBuilder.setMediaSize(strip80Size)
                                    } else {
                                        attributesBuilder.setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                                    }

                                    attributesBuilder.setColorMode(PrintAttributes.COLOR_MODE_MONOCHROME)

                                    printManager.print(jobName, printAdapter, attributesBuilder.build())
                                    result.success(true)
                                }
                            }
                            webView.loadDataWithBaseURL(null, htmlContent, "text/html; charset=utf-8", "UTF-8", null)
                        }
                    } catch (e: Exception) {
                        result.error("PRINT_EXCEPTION", e.localizedMessage, null)
                    }
                }
                "openPrintSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_PRINT_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 4. Canal nativo para Impresoras Térmicas BLUETOOTH REALES
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLUETOOTH_CHANNEL).setMethodCallHandler { call, result ->
            val adapter = getBluetoothAdapter()

            when (call.method) {
                "isBluetoothAvailable" -> {
                    result.success(adapter != null)
                }

                "isBluetoothEnabled" -> {
                    result.success(adapter?.isEnabled == true)
                }

                "requestEnableBluetooth" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ENABLE_ERROR", e.localizedMessage, null)
                    }
                }

                "getPairedPrinters" -> {
                    if (adapter == null) {
                        result.error("NO_ADAPTER", "El dispositivo no tiene Bluetooth", null)
                        return@setMethodCallHandler
                    }
                    if (!adapter.isEnabled) {
                        result.success(emptyList<Map<String, Any>>())
                        return@setMethodCallHandler
                    }

                    try {
                        val pairedList = mutableListOf<Map<String, Any>>()
                        val bondedDevices = adapter.bondedDevices ?: emptySet()

                        for (dev in bondedDevices) {
                            val name = dev.name ?: "Impresora Bluetooth"
                            pairedList.add(
                                mapOf(
                                    "id" to dev.address,
                                    "name" to name,
                                    "address" to dev.address,
                                    "type" to "bluetooth",
                                    "rssi" to -45,
                                    "paperWidth" to (if (name.contains("80") || name.contains("T20")) 80 else 58),
                                    "isPaired" to true
                                )
                            )
                        }
                        result.success(pairedList)
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", "Permiso de Bluetooth no concedido: ${e.localizedMessage}", null)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.localizedMessage, null)
                    }
                }

                "startDiscovery" -> {
                    if (adapter == null || !adapter.isEnabled) {
                        result.error("BT_DISABLED", "Bluetooth no está encendido", null)
                        return@setMethodCallHandler
                    }

                    try {
                        discoveredDevicesList.clear()

                        // Si ya había un receptor registrado, desregistrarlo
                        discoveryReceiver?.let {
                            try { unregisterReceiver(it) } catch (_: Exception) {}
                        }

                        discoveryReceiver = object : BroadcastReceiver() {
                            override fun onReceive(ctx: Context?, intent: Intent?) {
                                when (intent?.action) {
                                    BluetoothDevice.ACTION_FOUND -> {
                                        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                                        } else {
                                            @Suppress("DEPRECATION")
                                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                                        }
                                        val rssi: Short = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)

                                        if (device != null && !device.address.isNullOrEmpty()) {
                                            val name = device.name ?: "Dispositivo Bluetooth"
                                            val alreadyExists = discoveredDevicesList.any { it["address"] == device.address }
                                            if (!alreadyExists) {
                                                discoveredDevicesList.add(
                                                    mapOf(
                                                        "id" to device.address,
                                                        "name" to name,
                                                        "address" to device.address,
                                                        "type" to "bluetooth",
                                                        "rssi" to rssi.toInt(),
                                                        "paperWidth" to (if (name.contains("80") || name.contains("T20")) 80 else 58),
                                                        "isPaired" to (device.bondState == BluetoothDevice.BOND_BONDED)
                                                    )
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
                        registerReceiver(discoveryReceiver, filter)

                        if (adapter.isDiscovering) {
                            adapter.cancelDiscovery()
                        }
                        adapter.startDiscovery()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DISCOVERY_ERROR", e.localizedMessage, null)
                    }
                }

                "getDiscoveredDevices" -> {
                    result.success(ArrayList(discoveredDevicesList))
                }

                "stopDiscovery" -> {
                    try {
                        adapter?.cancelDiscovery()
                        discoveryReceiver?.let {
                            try { unregisterReceiver(it) } catch (_: Exception) {}
                            discoveryReceiver = null
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.localizedMessage, null)
                    }
                }

                "printBluetoothEscPos" -> {
                    val address = call.argument<String>("address")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (address.isNullOrEmpty() || bytes == null) {
                        result.error("INVALID_ARGS", "Dirección o bytes nulos", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        var socket: BluetoothSocket? = null
                        try {
                            val device = adapter?.getRemoteDevice(address)
                            if (device == null) {
                                runOnUiThread { result.error("DEVICE_NOT_FOUND", "No se encontró el dispositivo con dirección $address", null) }
                                return@Thread
                            }

                            // SPP UUID estándar para impresoras térmicas ESC/POS
                            val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                            socket = device.createRfcommSocketToServiceRecord(sppUuid)

                            try {
                                adapter?.cancelDiscovery()
                            } catch (_: Exception) {}

                            socket.connect()
                            val outputStream = socket.outputStream
                            outputStream.write(bytes)
                            outputStream.flush()
                            Thread.sleep(250) // Pausa de vaciado de búfer térmico

                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PRINT_FAILED", "Fallo al imprimir por Bluetooth: ${e.localizedMessage}", null) }
                        } finally {
                            try {
                                socket?.close()
                            } catch (_: Exception) {}
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }

        // 5. Canal nativo para Impresoras Térmicas USB OTG REALES
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USB_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUsbPrinters" -> {
                    try {
                        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
                        val deviceList = usbManager?.deviceList ?: emptyMap()
                        val resultList = mutableListOf<Map<String, Any>>()

                        for (dev in deviceList.values) {
                            val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                dev.productName ?: dev.deviceName
                            } else {
                                dev.deviceName
                            }
                            resultList.add(
                                mapOf(
                                    "id" to "usb_${dev.deviceId}",
                                    "name" to (name ?: "Impresora USB OTG"),
                                    "address" to "USB:${dev.vendorId}:${dev.productId}",
                                    "type" to "usb",
                                    "rssi" to -15,
                                    "paperWidth" to 80,
                                    "isPaired" to true
                                )
                            )
                        }
                        result.success(resultList)
                    } catch (e: Exception) {
                        result.error("USB_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null

        discoveryReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
            discoveryReceiver = null
        }

        super.onDestroy()
    }
}
