package com.scrapwell.partner

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startService(Intent(this, AppCleanupService::class.java))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
