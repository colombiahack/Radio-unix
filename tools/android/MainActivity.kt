package PACKAGE_NAME

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        var channel: MethodChannel? = null
        var updateChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val ch = MethodChannel(messenger, "redunix/alarm")
        channel = ch
        ch.setMethodCallHandler { call, result -> AlarmBridge.handle(this, call, result) }
        val uc = MethodChannel(messenger, "redunix/update")
        updateChannel = uc
        uc.setMethodCallHandler { call, result -> Updater.handle(this, call, result) }
    }
}
