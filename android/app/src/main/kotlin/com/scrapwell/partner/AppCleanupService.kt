package com.scrapwell.partner

import android.app.Service
import android.content.Intent
import android.os.IBinder

class AppCleanupService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        try {
            val geolocatorIntent = Intent()
            geolocatorIntent.setClassName(this, "com.baseflow.geolocator.GeolocatorForegroundService")
            stopService(geolocatorIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        stopSelf()
    }
}
