package dev.elingeyes.correspondencia.t4_movil

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.os.Build

class MainActivity : FlutterActivity() {
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
    }
}
