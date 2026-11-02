package PACKAGE_NAME

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            AlarmBridge.rearm(context)
        } catch (e: Exception) {
        }
    }
}
