package com.scrapwell.partner

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue

class AppCleanupService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        
        try {
            val uid = FirebaseAuth.getInstance().currentUser?.uid
            if (uid != null) {
                val db = FirebaseFirestore.getInstance()
                
                // Immediately set offline in partners collection
                val updates = mapOf(
                    "isOnline" to false,
                    "isAvailable" to false,
                    "updatedAt" to FieldValue.serverTimestamp()
                )
                db.collection("partners").document(uid).update(updates)
                
                // Immediately set offline/unavailable in live_locations collection
                val liveUpdates = mapOf(
                    "isOnline" to false,
                    "isAvailable" to false,
                    "assignedOrderId" to null,
                    "updatedAt" to FieldValue.serverTimestamp()
                )
                db.collection("live_locations").document(uid).update(liveUpdates)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            val geolocatorIntent = Intent()
            geolocatorIntent.setClassName(this, "com.baseflow.geolocator.GeolocatorForegroundService")
            stopService(geolocatorIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        stopSelf()

        // Wait a short moment (500ms) for the network packets to be sent before killing the process
        try {
            Thread.sleep(500)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        android.os.Process.killProcess(android.os.Process.myPid())
    }
}
