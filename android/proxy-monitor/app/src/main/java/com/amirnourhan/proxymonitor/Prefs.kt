package com.amirnourhan.proxymonitor

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object Prefs {
    private const val FILE = "proxy_monitor_prefs"
    private const val KEY_URL = "router_url"
    private const val KEY_CONNECTED = "persistent_connected"
    private const val KEY_DISCONNECT_REASON = "last_disconnect_reason"
    private const val KEY_SNAPSHOT = "last_snapshot"
    private const val KEY_ERROR = "last_refresh_error"
    private const val KEY_RATE_DOWN = "last_rate_down"
    private const val KEY_RATE_UP = "last_rate_up"
    private const val KEY_FULL_WIDGET_TAB_PREFIX = "full_widget_tab_"
    private const val KEY_APP_TAB = "app_tab"
    private const val KEY_AUTO_IP_REFRESH = "auto_ip_refresh"
    private const val KEY_LAST_OBSERVED_IP = "last_observed_public_ip"
    private const val KEY_LAST_AUTO_IP_ATTEMPT = "last_auto_ip_attempt"
    private const val KEY_REFRESH_NOTICE = "last_refresh_notice"
    private const val KEY_LAST_REFRESH_WAS_IP_CHANGE = "last_refresh_was_ip_change"

    const val DEFAULT_URL = "http://192.168.28.1/cgi-bin/proxy-monitor-mobile"

    fun url(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_URL, DEFAULT_URL)
            ?.trim()
            .orEmpty()
            .ifBlank { DEFAULT_URL }

    fun save(context: Context, url: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_URL, url.trim().ifBlank { DEFAULT_URL })
            .putString(KEY_LAST_OBSERVED_IP, "")
            .putLong(KEY_LAST_AUTO_IP_ATTEMPT, 0L)
            .putString(KEY_REFRESH_NOTICE, "")
            .apply()
    }

    fun isConnected(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getBoolean(KEY_CONNECTED, false)

    fun setConnected(context: Context, connected: Boolean) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_CONNECTED, connected)
            .apply()
    }

    fun setDisconnectReason(context: Context, reason: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_DISCONNECT_REASON, reason.take(160))
            .apply()
    }

    fun clearDisconnectReason(context: Context) = setDisconnectReason(context, "")

    fun disconnectReason(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_DISCONNECT_REASON, "")
            .orEmpty()

    fun fullWidgetTab(context: Context, appWidgetId: Int): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString("$KEY_FULL_WIDGET_TAB_PREFIX$appWidgetId", "monitor")
            .orEmpty()
            .ifBlank { "monitor" }

    fun setFullWidgetTab(context: Context, appWidgetId: Int, tab: String) {
        if (appWidgetId == android.appwidget.AppWidgetManager.INVALID_APPWIDGET_ID) return
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(
                "$KEY_FULL_WIDGET_TAB_PREFIX$appWidgetId",
                if (tab == "passwall2") "passwall2" else "monitor"
            )
            .apply()
    }

    fun appTab(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_APP_TAB, "monitor")
            .orEmpty()
            .ifBlank { "monitor" }

    fun setAppTab(context: Context, tab: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_APP_TAB, if (tab == "passwall2") "passwall2" else "monitor")
            .apply()
    }

    fun autoIpRefresh(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getBoolean(KEY_AUTO_IP_REFRESH, true)

    fun setAutoIpRefresh(context: Context, enabled: Boolean) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_AUTO_IP_REFRESH, enabled)
            .apply()
    }

    fun lastObservedPublicIp(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_LAST_OBSERVED_IP, "")
            .orEmpty()

    fun setLastObservedPublicIp(context: Context, ip: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_OBSERVED_IP, ip.trim().take(64))
            .apply()
    }

    fun lastAutoIpAttempt(context: Context): Long =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getLong(KEY_LAST_AUTO_IP_ATTEMPT, 0L)

    fun setLastAutoIpAttempt(context: Context, timestampMs: Long) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_AUTO_IP_ATTEMPT, timestampMs)
            .apply()
    }

    fun refreshNotice(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_REFRESH_NOTICE, "")
            .orEmpty()

    fun setRefreshNotice(context: Context, message: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_REFRESH_NOTICE, message.take(180))
            .apply()
    }

    fun clearRefreshNotice(context: Context) = setRefreshNotice(context, "")

    fun setLastRefreshWasIpChange(context: Context, wasIpChange: Boolean) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LAST_REFRESH_WAS_IP_CHANGE, wasIpChange)
            .apply()
    }

    fun lastRefreshWasIpChange(context: Context): Boolean =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getBoolean(KEY_LAST_REFRESH_WAS_IP_CHANGE, false)

    fun setLastError(context: Context, error: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ERROR, error.take(240))
            .apply()
    }

    fun clearLastError(context: Context) = setLastError(context, "")

    fun lastError(context: Context): String =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_ERROR, "")
            .orEmpty()

    fun saveSnapshot(context: Context, snapshot: MonitorSnapshot, rate: TrafficRate) {
        val nodes = JSONArray()
        snapshot.nodes.forEach { node ->
            nodes.put(
                JSONObject()
                    .put("name", node.name)
                    .put("group", node.group)
                    .put("ping_ms", node.pingMs ?: JSONObject.NULL)
            )
        }

        val json = JSONObject()
            .put("public_ip", snapshot.publicIp)
            .put("country_code", snapshot.countryCode)
            .put("xray_running", snapshot.xrayRunning)
            .put("singbox_running", snapshot.singboxRunning)
            .put("selected_remark", snapshot.selectedRemark)
            .put("selected_type", snapshot.selectedType)
            .put("selected_protocol", snapshot.selectedProtocol)
            .put("expected_nodes", snapshot.expectedNodes)
            .put("active_nodes", nodes)
            .put("device", snapshot.device)
            .put("rx_bytes", snapshot.rxBytes)
            .put("tx_bytes", snapshot.txBytes)
            .put("fetched_at_ms", snapshot.fetchedAtMs)

        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT, json.toString())
            .putLong(KEY_RATE_DOWN, java.lang.Double.doubleToRawLongBits(rate.downloadBytesPerSec))
            .putLong(KEY_RATE_UP, java.lang.Double.doubleToRawLongBits(rate.uploadBytesPerSec))
            .putString(KEY_ERROR, "")
            .apply()
    }

    fun lastSnapshot(context: Context): MonitorSnapshot? {
        val raw = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT, null)
            ?: return null

        return runCatching {
            val json = JSONObject(raw)
            val array = json.optJSONArray("active_nodes") ?: JSONArray()
            val nodes = mutableListOf<NodeInfo>()

            for (index in 0 until array.length()) {
                val node = array.optJSONObject(index) ?: continue
                val ping = if (node.has("ping_ms") && !node.isNull("ping_ms")) {
                    node.optDouble("ping_ms").takeIf { !it.isNaN() }
                } else {
                    null
                }
                nodes += NodeInfo(
                    name = node.optString("name"),
                    group = node.optString("group"),
                    pingMs = ping
                )
            }

            MonitorSnapshot(
                publicIp = json.optString("public_ip"),
                countryCode = json.optString("country_code"),
                xrayRunning = json.optBoolean("xray_running", false),
                singboxRunning = json.optBoolean("singbox_running", false),
                selectedRemark = json.optString("selected_remark"),
                selectedType = json.optString("selected_type"),
                selectedProtocol = json.optString("selected_protocol"),
                expectedNodes = json.optInt("expected_nodes", 0),
                nodes = nodes,
                device = json.optString("device"),
                rxBytes = json.optLong("rx_bytes", 0L),
                txBytes = json.optLong("tx_bytes", 0L),
                fetchedAtMs = json.optLong("fetched_at_ms", 0L)
            )
        }.getOrNull()
    }

    fun lastRate(context: Context): TrafficRate {
        val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        return TrafficRate(
            downloadBytesPerSec = java.lang.Double.longBitsToDouble(
                prefs.getLong(KEY_RATE_DOWN, java.lang.Double.doubleToRawLongBits(0.0))
            ),
            uploadBytesPerSec = java.lang.Double.longBitsToDouble(
                prefs.getLong(KEY_RATE_UP, java.lang.Double.doubleToRawLongBits(0.0))
            )
        )
    }
}
