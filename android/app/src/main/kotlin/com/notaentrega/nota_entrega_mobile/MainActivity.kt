package com.notaentrega.nota_entrega_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity : FlutterActivity() {
    private lateinit var rifScanner: RifScanner

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        rifScanner = RifScanner(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Forward platform results to the scanner and Flutter plugins")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::rifScanner.isInitialized) rifScanner.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        if (::rifScanner.isInitialized) rifScanner.close()
        super.onDestroy()
    }
}
