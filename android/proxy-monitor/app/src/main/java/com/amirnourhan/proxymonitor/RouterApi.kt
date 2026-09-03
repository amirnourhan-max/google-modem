package com.amirnourhan.proxymonitor

import android.net.Uri
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL

object RouterApi {
    private const val PUBLIC_IP_PROBE_URL = "https://api.ipify.org"

    fun fetch(urlText: String): MonitorSnapshot {
        val freshUrl = Uri.parse(urlText)
            .buildUpon()
            .appendQueryParameter("fresh", "1")
            .build()
            .toString()
        val connection = (URL(freshUrl).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 8000
            readTimeout = 90000
            useCaches = false
            setRequestProperty("Accept", "application/json")
        }

        try {
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (code !in 200..299) {
                throw IllegalStateException("Router API HTTP $code: ${body.take(180)}")
            }

            val root = JSONObject(body)
            val status = root.optJSONObject("status") ?: JSONObject()
            val traffic = root.optJSONObject("traffic") ?: JSONObject()
            val nodesJson = status.optJSONArray("active_nodes")
            val nodes = mutableListOf<NodeInfo>()

            if (nodesJson != null) {
                for (i in 0 until nodesJson.length()) {
                    val n = nodesJson.optJSONObject(i) ?: continue
                    val ping = if (n.has("ping_ms") && !n.isNull("ping_ms")) n.optDouble("ping_ms") else null
                    nodes += NodeInfo(
                        name = n.optString("name"),
                        group = n.optString("group"),
                        pingMs = ping?.takeIf { !it.isNaN() }
                    )
                }
            }

            return MonitorSnapshot(
                publicIp = status.optString("public_ip"),
                countryCode = status.optString("country_code"),
                xrayRunning = status.optBoolean("xray_running", false),
                singboxRunning = status.optBoolean("singbox_running", false),
                selectedRemark = status.optString("selected_remark"),
                selectedType = status.optString("selected_type"),
                selectedProtocol = status.optString("selected_protocol"),
                expectedNodes = status.optInt("expected_nodes", 0),
                nodes = nodes,
                device = traffic.optString("device"),
                rxBytes = traffic.optLong("rx_bytes", 0L),
                txBytes = traffic.optLong("tx_bytes", 0L),
                fetchedAtMs = System.currentTimeMillis()
            )
        } catch (e: SocketTimeoutException) {
            throw IllegalStateException(
                "Router response exceeded 90s. Install router API v6.",
                e
            )
        } finally {
            connection.disconnect()
        }
    }

    fun fetchPublicIp(): String {
        val connection = (URL(PUBLIC_IP_PROBE_URL).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 5000
            readTimeout = 5000
            useCaches = false
            setRequestProperty("Accept", "text/plain")
            setRequestProperty("User-Agent", "ProxyMonitorAndroid/2.11")
        }

        try {
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("Public IP probe HTTP $code")
            }
            val value = connection.inputStream.bufferedReader().use { it.readText() }.trim()
            if (!isValidIpv4(value)) {
                throw IllegalStateException("Public IP probe returned invalid IPv4")
            }
            return value
        } finally {
            connection.disconnect()
        }
    }

    private fun isValidIpv4(value: String): Boolean {
        val parts = value.split('.')
        if (parts.size != 4) return false
        return parts.all { part ->
            part.isNotEmpty() &&
                part.length <= 3 &&
                part.all { it.isDigit() } &&
                (part.toIntOrNull()?.let { it in 0..255 } == true)
        }
    }
}
