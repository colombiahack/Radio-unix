package PACKAGE_NAME

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val svc = Intent(context, AlarmService::class.java)
        svc.putExtra("aid", intent.getIntExtra("aid", -1))
        svc.putExtra("name", intent.getStringExtra("name") ?: "Radio Mundo")
        svc.putExtra("url", intent.getStringExtra("url") ?: "")
        if (Build.VERSION.SDK_INT >= 26) {
            context.startForegroundService(svc)
        } else {
            context.startService(svc)
        }
    }
}
