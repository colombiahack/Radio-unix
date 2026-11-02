package PACKAGE_NAME

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

object AlarmBridge {
    private const val PREFS = "redunix_alarms"
    private const val KEY = "list"

    private fun flags(): Int {
        val imm = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        return imm or PendingIntent.FLAG_UPDATE_CURRENT
    }

    private fun receiverIntent(ctx: Context, aid: Int, name: String, url: String): Intent {
        val i = Intent(ctx, AlarmReceiver::class.java)
        i.putExtra("aid", aid)
        i.putExtra("name", name)
        i.putExtra("url", url)
        return i
    }

    private fun setOne(ctx: Context, id: Int, t: Long, aid: Int, name: String, url: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(ctx, id, receiverIntent(ctx, aid, name, url), flags())
        val show = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), flags())
        try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(t, show), pi)
        } catch (e: SecurityException) {
            if (Build.VERSION.SDK_INT >= 23) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, t, pi)
            }
        }
    }

    private fun stored(ctx: Context): String {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]") ?: "[]"
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val arr = JSONArray(stored(ctx))
        for (n in 0 until arr.length()) {
            val o = arr.getJSONObject(n)
            val pi = PendingIntent.getBroadcast(ctx, o.getInt("id"), receiverIntent(ctx, 0, "", ""), flags())
            am.cancel(pi)
            pi.cancel()
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, "[]").apply()
    }

    fun schedule(ctx: Context, items: List<*>) {
        cancelAll(ctx)
        val arr = JSONArray()
        val now = System.currentTimeMillis()
        for (item in items) {
            val m = item as? Map<*, *> ?: continue
            val id = (m["id"] as Number).toInt()
            val t = (m["t"] as Number).toLong()
            val aid = (m["aid"] as Number).toInt()
            val name = (m["name"] as? String) ?: ""
            val url = (m["url"] as? String) ?: ""
            if (t <= now) continue
            setOne(ctx, id, t, aid, name, url)
            val o = JSONObject()
            o.put("id", id)
            o.put("t", t)
            o.put("aid", aid)
            o.put("name", name)
            o.put("url", url)
            arr.put(o)
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    fun rearm(ctx: Context) {
        val arr = JSONArray(stored(ctx))
        val now = System.currentTimeMillis()
        for (n in 0 until arr.length()) {
            val o = arr.getJSONObject(n)
            val t = o.getLong("t")
            if (t > now) {
                setOne(ctx, o.getInt("id"), t, o.getInt("aid"), o.getString("name"), o.getString("url"))
            }
        }
    }

    fun handle(act: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                schedule(act, (call.arguments as? List<*>) ?: emptyList<Any>())
                result.success(true)
            }
            "cancelAll" -> {
                cancelAll(act)
                result.success(true)
            }
            "canExact" -> {
                val am = act.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                result.success(Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms())
            }
            "requestExact" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    try {
                        val i = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        i.data = Uri.parse("package:" + act.packageName)
                        act.startActivity(i)
                    } catch (e: Exception) {
                    }
                }
                result.success(true)
            }
            "ringing" -> {
                if (AlarmService.ringingAid >= 0) {
                    result.success(mapOf("aid" to AlarmService.ringingAid, "name" to AlarmService.ringingName))
                } else {
                    result.success(null)
                }
            }
            "stop" -> {
                act.stopService(Intent(act, AlarmService::class.java))
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
