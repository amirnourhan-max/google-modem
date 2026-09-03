package com.amirnourhan.proxymonitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ConnectionBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val shouldResume = intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED

        if (!shouldResume) return

        WidgetCoordinator.showCurrent(context)
        if (Prefs.isConnected(context)) {
            runCatching { PersistentConnectionService.ensureRunning(context) }
        }
    }
}
