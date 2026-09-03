package com.amirnourhan.proxymonitor

import android.content.Context
import android.net.Uri

object RouterLinks {
    fun passWallUri(context: Context): Uri {
        return runCatching {
            val router = Uri.parse(Prefs.url(context))
            require(router.scheme == "http" || router.scheme == "https")
            require(!router.host.isNullOrBlank())
            router.buildUpon()
                .encodedPath("/cgi-bin/luci/admin/services/passwall2")
                .clearQuery()
                .fragment(null)
                .build()
        }.getOrElse {
            Uri.parse("http://192.168.28.1/cgi-bin/luci/admin/services/passwall2")
        }
    }

    fun routerHost(context: Context): String =
        Uri.parse(Prefs.url(context)).host?.takeIf { it.isNotBlank() } ?: "router"
}
