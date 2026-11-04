package PACKAGE_NAME

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

object Updater {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var busy = false

    fun post(method: String, args: Any?) {
        main.post {
            try {
                MainActivity.updateChannel?.invokeMethod(method, args)
            } catch (e: Exception) {
            }
        }
    }

    fun handle(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val url = call.argument<String>("url") ?: ""
                start(ctx.applicationContext, url)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(ctx: Context, url: String) {
        if (busy) return
        if (Build.VERSION.SDK_INT >= 26 && !ctx.packageManager.canRequestPackageInstalls()) {
            try {
                val i = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                i.data = Uri.parse("package:" + ctx.packageName)
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(i)
            } catch (e: Exception) {
            }
            post("status", mapOf("s" to "needPermission", "m" to ""))
            return
        }
        busy = true
        Thread {
            try {
                download(ctx, url)
            } catch (e: Exception) {
                busy = false
                post("status", mapOf("s" to "error", "m" to (e.message ?: "error")))
            }
        }.start()
    }

    private fun download(ctx: Context, url: String) {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.instanceFollowRedirects = true
        conn.connectTimeout = 15000
        conn.readTimeout = 30000
        conn.connect()
        if (conn.responseCode != 200) {
            throw Exception("Descarga fallida (HTTP " + conn.responseCode + ")")
        }
        val total = conn.contentLength.toLong()
        val file = File(ctx.cacheDir, "update.apk")
        var done = 0L
        var last = -1
        conn.inputStream.use { input ->
            FileOutputStream(file).use { out ->
                val buf = ByteArray(65536)
                var n = input.read(buf)
                while (n >= 0) {
                    out.write(buf, 0, n)
                    done += n
                    if (total > 0) {
                        val pct = (done * 100 / total).toInt()
                        if (pct != last) {
                            last = pct
                            post("progress", pct)
                        }
                    }
                    n = input.read(buf)
                }
            }
        }
        post("status", mapOf("s" to "installing", "m" to ""))
        install(ctx, file)
    }

    private fun install(ctx: Context, file: File) {
        val installer = ctx.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val id = installer.createSession(params)
        val session = installer.openSession(id)
        file.inputStream().use { input ->
            session.openWrite("update.apk", 0, file.length()).use { out ->
                input.copyTo(out)
                session.fsync(out)
            }
        }
        val intent = Intent(ctx, InstallReceiver::class.java)
        val mutable = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        val pending = PendingIntent.getBroadcast(ctx, id, intent, mutable or PendingIntent.FLAG_UPDATE_CURRENT)
        session.commit(pending.intentSender)
        session.close()
        busy = false
    }
}
