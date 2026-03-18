package com.tuempresa.motogps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Se ejecuta cuando el dispositivo arranca.
 * Aquí puedes reiniciar el tracking si estaba activo antes del reinicio.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            // TODO: Reiniciar tracking si SharedPreferences indica que estaba activo
        }
    }
}
