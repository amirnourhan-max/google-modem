package com.amirnourhan.proxymonitor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class PersistentConnectionService : Service() {
    companion object {
        const val ACTION_STATE_CHANGED = "com.amirnourhan.proxymonitor.STATE_CHANGED_V3"
        private const val ACTION_CONNECT = "com.amirnourhan.proxymonitor.CONNECT"
        private const val ACTION_DISCONNECT = "com.amirnourhan.proxymonitor.DISCONNECT"
        private const val ACTION_REFRESH = "com.amirnourhan.proxymonitor.SERVICE_REFRESH"
        private const val ACTION_CHECK_IP = "com.amirnourhan.proxymonitor.SERVICE_CHECK_IP"
        private const val CHANNEL_ID = "proxy_monitor_connection_v1"
        private const val NOTIFICATION_ID = 2401
        private const val WIFI_LOST_REASON = "Wi-Fi disconnected • connection stopped"

        fun connect(context: Context) {
            if (!isWifiConnected(context)) {
                Prefs.setConnected(context, false)
                Prefs.clearLastError(context)
                Prefs.setDisconnectReason(context, "Wi-Fi is off • turn it on, then tap Connect")
                WidgetCoordinator.showCurrent(context)
                context.sendBroadcast(Intent(ACTION_STATE_CHANGED).setPackage(context.packageName))
                throw IllegalStateException("Connect to Wi-Fi first")
            }
            Prefs.setConnected(context, true)
            Prefs.clearLastError(context)
            Prefs.clearDisconnectReason(context)
            try {
                start(context, ACTION_CONNECT)
            } catch (e: Exception) {
                Prefs.setConnected(context, false)
                Prefs.setDisconnectReason(context, "Could not start connection")
                WidgetCoordinator.showCurrent(context)
                throw e
            }
        }

        fun ensureRunning(context: Context) {
            if (!Prefs.isConnected(context)) return
            if (!isWifiConnected(context)) {
                disconnect(context, WIFI_LOST_REASON)
                return
            }
            start(context, ACTION_CONNECT)
        }

        fun disconnect(context: Context, reason: String = "Disconnected by user") {
            Prefs.setConnected(context, false)
            Prefs.clearLastError(context)
            Prefs.setDisconnectReason(context, reason)
            context.stopService(Intent(context, PersistentConnectionService::class.java))
            WidgetCoordinator.showCurrent(context)
            context.sendBroadcast(Intent(ACTION_STATE_CHANGED).setPackage(context.packageName))
        }

        fun requestRefresh(context: Context) {
            if (!Prefs.isConnected(context)) return
            if (!isWifiConnected(context)) {
                disconnect(context, WIFI_LOST_REASON)
                throw IllegalStateException("Wi-Fi disconnected")
            }
            start(context, ACTION_REFRESH)
        }

        fun requestIpCheck(context: Context) {
            if (!Prefs.isConnected(context) || !Prefs.autoIpRefresh(context)) return
            if (!isWifiConnected(context)) return
            start(context, ACTION_CHECK_IP)
        }

        fun isWifiConnected(context: Context): Boolean {
            val manager = context.getSystemService(ConnectivityManager::class.java)
            return runCatching {
                manager.allNetworks.any { network ->
                    manager.getNetworkCapabilities(network)
                        ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
                }
            }.getOrDefault(false)
        }

        private fun start(context: Context, action: String) {
            val intent = Intent(context, PersistentConnectionService::class.java).setAction(action)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private val refreshing = AtomicBoolean(false)
    private val disconnecting = AtomicBoolean(false)
    private val ipMonitorStarted = AtomicBoolean(false)
    private val executor = Executors.newSingleThreadExecutor()
    private val ipMonitorExecutor = Executors.newSingleThreadScheduledExecutor()
    private val wifiHandler = Handler(Looper.getMainLooper())
    private var wifiCallbackRegistered = false
    private val verifyWifiLoss = Runnable {
        if (Prefs.isConnected(this) && !isWifiConnected(this)) {
            disconnectInternal(WIFI_LOST_REASON)
        }
    }
    private val wifiCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            wifiHandler.removeCallbacks(verifyWifiLoss)
        }

        override fun onLost(network: Network) {
            wifiHandler.removeCallbacks(verifyWifiLoss)
            wifiHandler.postDelayed(verifyWifiLoss, 600L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerWifiMonitor()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            disconnectInternal("Disconnected by user")
            return START_NOT_STICKY
        }

        if (intent?.action == ACTION_CONNECT) {
            if (!isWifiConnected(this)) {
                disconnectInternal(WIFI_LOST_REASON)
                return START_NOT_STICKY
            }
            Prefs.setConnected(this, true)
            Prefs.clearDisconnectReason(this)
        }

        if (!Prefs.isConnected(this)) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        if (!isWifiConnected(this)) {
            disconnectInternal(WIFI_LOST_REASON)
            return START_NOT_STICKY
        }

        startAsForeground(currentNotificationText())
        startIpMonitor()

        if (intent?.action == ACTION_REFRESH) {
            refreshOnce()
        } else if (intent?.action == ACTION_CHECK_IP) {
            ipMonitorExecutor.execute { checkForIpChange() }
        }

        return START_STICKY
    }

    private data class IpChange(val oldIp: String, val newIp: String)

    private fun refreshOnce(ipChange: IpChange? = null) {
        if (!refreshing.compareAndSet(false, true)) return
        if (ipChange == null) {
            Prefs.clearRefreshNotice(this)
            updateNotification("Refreshing router…")
        } else {
            updateNotification("Public IP changed • refreshing router…")
        }

        executor.execute {
            try {
                val fetched = RouterApi.fetch(Prefs.url(this))
                if (!Prefs.isConnected(this)) return@execute
                val snapshot = if (ipChange != null && fetched.publicIp != ipChange.newIp) {
                    fetched.copy(publicIp = ipChange.newIp, countryCode = "")
                } else {
                    fetched
                }
                val rate = TrafficRateStore.update(
                    this,
                    snapshot.rxBytes,
                    snapshot.txBytes,
                    snapshot.fetchedAtMs
                )
                Prefs.saveSnapshot(this, snapshot, rate)
                if (snapshot.publicIp.isNotBlank()) {
                    Prefs.setLastObservedPublicIp(this, snapshot.publicIp)
                }
                if (ipChange != null) {
                    Prefs.setRefreshNotice(
                        this,
                        "Auto-refreshed after Public IP changed: ${ipChange.oldIp} → ${snapshot.publicIp}"
                    )
                }
                Prefs.setLastRefreshWasIpChange(this, ipChange != null)
                WidgetCoordinator.renderFromSnapshot(this, snapshot, rate)

                val ip = snapshot.publicIp.ifBlank { "Router online" }
                val notificationText = if (ipChange == null) {
                    "Last refresh ${Formatters.updated(snapshot.fetchedAtMs)} • $ip"
                } else {
                    "IP changed • refreshed ${Formatters.updated(snapshot.fetchedAtMs)} • $ip"
                }
                updateNotification(notificationText)
            } catch (e: Exception) {
                if (!Prefs.isConnected(this)) return@execute
                val error = e.message ?: "Router unavailable"
                Prefs.setLastError(this, error)
                WidgetCoordinator.showRefreshError(this, error)
                updateNotification("Connected • refresh failed: ${error.take(72)}")
            } finally {
                refreshing.set(false)
                broadcastState()
            }
        }
    }

    private fun startIpMonitor() {
        if (!ipMonitorStarted.compareAndSet(false, true)) return
        ipMonitorExecutor.scheduleWithFixedDelay(
            { checkForIpChange() },
            10L,
            30L,
            TimeUnit.SECONDS
        )
    }

    private fun checkForIpChange() {
        if (!Prefs.isConnected(this) || !Prefs.autoIpRefresh(this)) return
        if (!isWifiConnected(this) || refreshing.get()) return

        val currentIp = runCatching { RouterApi.fetchPublicIp() }.getOrNull() ?: return
        val previousIp = Prefs.lastObservedPublicIp(this)
            .ifBlank { Prefs.lastSnapshot(this)?.publicIp.orEmpty() }

        if (previousIp.isBlank()) {
            Prefs.setLastObservedPublicIp(this, currentIp)
            return
        }
        if (currentIp == previousIp) return

        val now = System.currentTimeMillis()
        if (now - Prefs.lastAutoIpAttempt(this) < 60_000L) return
        Prefs.setLastAutoIpAttempt(this, now)
        refreshOnce(IpChange(previousIp, currentIp))
    }

    private fun registerWifiMonitor() {
        val manager = getSystemService(ConnectivityManager::class.java)
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        runCatching {
            manager.registerNetworkCallback(request, wifiCallback)
            wifiCallbackRegistered = true
        }
    }

    private fun disconnectInternal(reason: String) {
        if (!disconnecting.compareAndSet(false, true)) return
        Prefs.setConnected(this, false)
        Prefs.clearLastError(this)
        Prefs.setDisconnectReason(this, reason)
        WidgetCoordinator.showCurrent(this)
        broadcastState()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun currentNotificationText(): String {
        if (Prefs.lastError(this).isNotBlank()) {
            return "Connected • last refresh failed"
        }
        val snapshot = Prefs.lastSnapshot(this)
        return if (snapshot != null && snapshot.fetchedAtMs > 0L) {
            "Connected • last refresh ${Formatters.updated(snapshot.fetchedAtMs)}"
        } else if (Prefs.autoIpRefresh(this)) {
            "Connected • IP-change detection on"
        } else {
            "Connected • manual refresh only"
        }
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.connection_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps Proxy Monitor connected until Disconnect"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun startAsForeground(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            2401,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val refreshIntent = PendingIntent.getService(
            this,
            2402,
            Intent(this, PersistentConnectionService::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val disconnectIntent = PendingIntent.getService(
            this,
            2403,
            Intent(this, PersistentConnectionService::class.java).setAction(ACTION_DISCONNECT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Proxy Monitor • Connected")
            .setContentText(text)
            .setContentIntent(openIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(R.drawable.ic_notification, "Refresh", refreshIntent)
            .addAction(R.drawable.ic_notification, "Disconnect", disconnectIntent)
            .build()
    }

    private fun broadcastState() {
        sendBroadcast(Intent(ACTION_STATE_CHANGED).setPackage(packageName))
    }

    override fun onDestroy() {
        wifiHandler.removeCallbacks(verifyWifiLoss)
        if (wifiCallbackRegistered) {
            runCatching {
                getSystemService(ConnectivityManager::class.java)
                    .unregisterNetworkCallback(wifiCallback)
            }
        }
        executor.shutdownNow()
        ipMonitorExecutor.shutdownNow()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
