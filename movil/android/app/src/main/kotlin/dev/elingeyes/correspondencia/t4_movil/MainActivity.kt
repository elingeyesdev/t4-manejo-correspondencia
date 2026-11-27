package dev.elingeyes.correspondencia.t4_movil

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build
import android.app.Activity
import android.content.Intent

class MainActivity : FlutterActivity() {
    private data class PdfPendiente(val bytes: ByteArray, val result: MethodChannel.Result)
    private var pdfPendiente: PdfPendiente? = null
    private val guardarPdfRequest = 7601

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "correspondencia/notificaciones")
            .setMethodCallHandler { call, result ->
                val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "crearCanal" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = NotificationChannel("correspondencia", "Tareas de correspondencia", NotificationManager.IMPORTANCE_HIGH)
                            channel.description = "Avisos de revisión y recepción pendientes"
                            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                            manager.createNotificationChannel(channel)
                        }
                        result.success(null)
                    }
                    "cancelar" -> { manager.cancelAll(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "correspondencia/documentos")
            .setMethodCallHandler { call, result ->
                if (call.method != "guardarPdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val nombre = call.argument<String>("nombre")
                if (bytes == null || bytes.size < 5 || String(bytes.copyOfRange(0, 5), Charsets.US_ASCII) != "%PDF-" || nombre.isNullOrBlank()) {
                    result.error("PDF_INVALIDO", "El documento no es un PDF válido.", null)
                } else if (pdfPendiente != null) {
                    result.error("DESCARGA_EN_CURSO", "Ya hay una descarga en curso.", null)
                } else {
                    pdfPendiente = PdfPendiente(bytes, result)
                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_TITLE, nombre)
                        }
                        startActivityForResult(intent, guardarPdfRequest)
                    } catch (_: Exception) {
                        pdfPendiente = null
                        result.error("GUARDADO_NO_DISPONIBLE", "No se pudo abrir la ubicación de guardado.", null)
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != guardarPdfRequest) return
        val pendiente = pdfPendiente ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pdfPendiente = null
            pendiente.result.success(false)
            return
        }
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri, "w") ?: throw IllegalStateException("Sin acceso al archivo")
                output.use { it.write(pendiente.bytes) }
                runOnUiThread {
                    pdfPendiente = null
                    pendiente.result.success(true)
                }
            } catch (_: Exception) {
                runOnUiThread {
                    pdfPendiente = null
                    pendiente.result.error("GUARDADO_FALLIDO", "No se pudo guardar el PDF.", null)
                }
            }
        }.start()
    }
}
