package com.amirnourhan.proxymonitor

import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object Formatters {
    private val oneDecimal = DecimalFormat("0.0")

    fun countryFlag(code: String): String {
        val cc = code.uppercase(Locale.US)
        if (cc.length != 2 || cc.any { it !in 'A'..'Z' }) return "🌐"
        val first = Character.codePointAt(cc, 0) - 'A'.code + 0x1F1E6
        val second = Character.codePointAt(cc, 1) - 'A'.code + 0x1F1E6
        return String(Character.toChars(first)) + String(Character.toChars(second))
    }

    fun rate(bytesPerSec: Double): String {
        val bits = bytesPerSec.coerceAtLeast(0.0) * 8.0
        return when {
            bits >= 1_000_000_000 -> "${oneDecimal.format(bits / 1_000_000_000)} Gbps"
            bits >= 1_000_000 -> "${oneDecimal.format(bits / 1_000_000)} Mbps"
            bits >= 1_000 -> "${oneDecimal.format(bits / 1_000)} Kbps"
            else -> "${bits.toInt()} bps"
        }
    }

    fun ping(ms: Double?): String = when {
        ms == null || ms <= 0.0 -> "—"
        ms < 100.0 -> "🟢 ${ms.toInt()} ms"
        ms < 200.0 -> "🟡 ${ms.toInt()} ms"
        else -> "🔴 ${ms.toInt()} ms"
    }

    fun updated(timeMs: Long): String =
        SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(timeMs))
}
