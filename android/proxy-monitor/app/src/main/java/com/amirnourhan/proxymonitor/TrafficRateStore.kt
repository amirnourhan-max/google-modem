package com.amirnourhan.proxymonitor

import android.content.Context

object TrafficRateStore {
    private const val FILE = "traffic_rate_state"

    fun update(context: Context, rx: Long, tx: Long, nowMs: Long): TrafficRate {
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val prevRx = p.getLong("rx", -1L)
        val prevTx = p.getLong("tx", -1L)
        val prevTs = p.getLong("ts", -1L)

        p.edit().putLong("rx", rx).putLong("tx", tx).putLong("ts", nowMs).apply()

        if (prevRx < 0 || prevTx < 0 || prevTs < 0 || nowMs <= prevTs) {
            return TrafficRate(0.0, 0.0)
        }

        val seconds = (nowMs - prevTs) / 1000.0
        if (seconds < 0.5 || seconds > 3600.0 || rx < prevRx || tx < prevTx) {
            return TrafficRate(0.0, 0.0)
        }

        return TrafficRate(
            downloadBytesPerSec = (rx - prevRx) / seconds,
            uploadBytesPerSec = (tx - prevTx) / seconds
        )
    }
}
