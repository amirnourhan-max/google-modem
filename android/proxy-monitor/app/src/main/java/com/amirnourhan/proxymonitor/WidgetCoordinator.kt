package com.amirnourhan.proxymonitor

import android.annotation.TargetApi
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews

object WidgetCoordinator {
    const val ACTION_REFRESH = "com.amirnourhan.proxymonitor.REFRESH_WIDGET_V2"
    const val ACTION_CONNECT = "com.amirnourhan.proxymonitor.CONNECT_WIDGET_V1"
    const val ACTION_DISCONNECT = "com.amirnourhan.proxymonitor.DISCONNECT_WIDGET_V1"
    const val ACTION_TAB_MONITOR = "com.amirnourhan.proxymonitor.TAB_MONITOR_WIDGET_V1"
    const val ACTION_TAB_PASSWALL2 = "com.amirnourhan.proxymonitor.TAB_PASSWALL2_WIDGET_V1"

    fun handleWidgetAction(context: Context, intent: Intent): Boolean {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        when (intent.action) {
            ACTION_REFRESH -> refreshAll(context)
            ACTION_CONNECT -> {
                runCatching { PersistentConnectionService.connect(context) }
                    .onFailure {
                        if (Prefs.disconnectReason(context).isBlank()) {
                            Prefs.setDisconnectReason(
                                context,
                                it.message?.takeIf { message -> message.isNotBlank() }
                                    ?: "Could not connect"
                            )
                        }
                    }
                showCurrent(context)
            }
            ACTION_DISCONNECT -> PersistentConnectionService.disconnect(context)
            ACTION_TAB_MONITOR -> {
                Prefs.setFullWidgetTab(context, widgetId, "monitor")
                showCurrent(context)
            }
            ACTION_TAB_PASSWALL2 -> {
                Prefs.setFullWidgetTab(context, widgetId, "passwall2")
                showCurrent(context)
            }
            else -> return false
        }
        return true
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val fullIds = manager.getAppWidgetIds(ComponentName(context, ProxyWidgetProvider::class.java))
        val compactIds = manager.getAppWidgetIds(ComponentName(context, CompactProxyWidgetProvider::class.java))
        if (fullIds.isEmpty() && compactIds.isEmpty()) return

        if (!Prefs.isConnected(context)) {
            showCurrent(context)
            return
        }

        fullIds.forEach { showFullLoading(context, manager, it) }
        compactIds.forEach { showCompactLoading(context, manager, it) }

        runCatching { PersistentConnectionService.requestRefresh(context) }
            .onFailure { showRefreshError(context, it.message ?: "Refresh failed") }
    }

    fun showCurrent(context: Context) {
        val connected = Prefs.isConnected(context)
        if (!connected) {
            val reason = Prefs.disconnectReason(context)
                .ifBlank { "Tap Connect on this widget" }
            val manager = AppWidgetManager.getInstance(context)
            val fullIds = manager.getAppWidgetIds(ComponentName(context, ProxyWidgetProvider::class.java))
            val compactIds = manager.getAppWidgetIds(ComponentName(context, CompactProxyWidgetProvider::class.java))
            fullIds.forEach {
                renderFullMessage(
                    context, manager, it,
                    "Disconnected", reason, "Wi-Fi required • tap Connect to resume", "#FCA5A5"
                )
            }
            compactIds.forEach {
                renderCompactMessage(context, manager, it, "Disconnected", reason, "#FCA5A5")
            }
            return
        }

        val snapshot = Prefs.lastSnapshot(context)
        if (snapshot != null) {
            renderFromSnapshot(context, snapshot, Prefs.lastRate(context))
            return
        }

        val manager = AppWidgetManager.getInstance(context)
        val fullIds = manager.getAppWidgetIds(ComponentName(context, ProxyWidgetProvider::class.java))
        val compactIds = manager.getAppWidgetIds(ComponentName(context, CompactProxyWidgetProvider::class.java))
        val heading = "✓ Connected"
        val detail = if (Prefs.autoIpRefresh(context)) {
            "Watching Public IP every 30s"
        } else {
            "Manual refresh only"
        }
        val hint = if (Prefs.autoIpRefresh(context)) {
            "Full refresh only after IP change • tap ↻ now"
        } else {
            "Tap ↻ to load router data"
        }
        val color = "#86EFAC"

        fullIds.forEach { renderFullMessage(context, manager, it, heading, detail, hint, color) }
        compactIds.forEach { renderCompactMessage(context, manager, it, heading, hint, color) }
    }

    fun renderFromSnapshot(context: Context, snapshot: MonitorSnapshot, rate: TrafficRate) {
        val manager = AppWidgetManager.getInstance(context)
        val fullIds = manager.getAppWidgetIds(ComponentName(context, ProxyWidgetProvider::class.java))
        val compactIds = manager.getAppWidgetIds(ComponentName(context, CompactProxyWidgetProvider::class.java))
        fullIds.forEach { renderFull(context, manager, it, snapshot, rate) }
        compactIds.forEach { renderCompact(context, manager, it, snapshot, rate) }
        if (fullIds.isNotEmpty() && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            manager.notifyAppWidgetViewDataChanged(fullIds, R.id.full_nodes_list)
        }
    }

    fun showRefreshError(context: Context, error: String) {
        if (!Prefs.isConnected(context)) {
            showCurrent(context)
            return
        }
        val manager = AppWidgetManager.getInstance(context)
        val fullIds = manager.getAppWidgetIds(ComponentName(context, ProxyWidgetProvider::class.java))
        val compactIds = manager.getAppWidgetIds(ComponentName(context, CompactProxyWidgetProvider::class.java))
        fullIds.forEach {
            renderFullMessage(
                context, manager, it,
                "⚠ Refresh failed • Connected", error.take(64), "Connection stays active • tap ↻ to retry", "#FCD34D"
            )
        }
        compactIds.forEach {
            renderCompactMessage(
                context, manager, it,
                "⚠ Refresh failed", "Still connected • tap ↻", "#FCD34D"
            )
        }
    }

    private fun openAppPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun widgetActionPendingIntent(
        context: Context,
        receiverClass: Class<*>,
        actionName: String,
        requestCode: Int,
        widgetId: Int
    ): PendingIntent {
        val intent = Intent(context, receiverClass).apply {
            action = actionName
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun fullBase(context: Context, widgetId: Int): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_proxy_monitor_full).apply {
            bindNodeList(this, context, widgetId)
            setEmptyView(R.id.full_nodes_list, R.id.full_nodes_empty)
            setOnClickPendingIntent(R.id.full_root, openAppPendingIntent(context, 10000 + widgetId))
            setOnClickPendingIntent(
                R.id.full_refresh,
                widgetActionPendingIntent(
                    context, ProxyWidgetProvider::class.java, ACTION_REFRESH, 20000 + widgetId, widgetId
                )
            )
            setOnClickPendingIntent(
                R.id.full_connect,
                widgetActionPendingIntent(
                    context, ProxyWidgetProvider::class.java, ACTION_CONNECT, 21000 + widgetId, widgetId
                )
            )
            setOnClickPendingIntent(
                R.id.full_disconnect,
                widgetActionPendingIntent(
                    context, ProxyWidgetProvider::class.java, ACTION_DISCONNECT, 22000 + widgetId, widgetId
                )
            )
            setOnClickPendingIntent(
                R.id.full_tab_monitor,
                widgetActionPendingIntent(
                    context, ProxyWidgetProvider::class.java, ACTION_TAB_MONITOR, 23000 + widgetId, widgetId
                )
            )
            setOnClickPendingIntent(
                R.id.full_tab_passwall2,
                widgetActionPendingIntent(
                    context, ProxyWidgetProvider::class.java, ACTION_TAB_PASSWALL2, 24000 + widgetId, widgetId
                )
            )
            setOnClickPendingIntent(
                R.id.full_open_passwall2,
                openPassWallPendingIntent(context, 25000 + widgetId)
            )
            applyFullConnectionControls(this, Prefs.isConnected(context))
            applyFullTab(this, Prefs.fullWidgetTab(context, widgetId) == "passwall2")
            applyFullSize(this, context, widgetId)
        }
    }

    private fun compactBase(context: Context, widgetId: Int): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_proxy_monitor_compact).apply {
            setOnClickPendingIntent(R.id.compact_root, openAppPendingIntent(context, 30000 + widgetId))
            setOnClickPendingIntent(
                R.id.compact_refresh,
                widgetActionPendingIntent(
                    context, CompactProxyWidgetProvider::class.java, ACTION_REFRESH, 40000 + widgetId, widgetId
                )
            )
            val connected = Prefs.isConnected(context)
            setTextViewText(R.id.compact_connection, if (connected) "Disconnect" else "Connect")
            setTextColor(
                R.id.compact_connection,
                Color.parseColor(if (connected) "#FCA5A5" else "#86EFAC")
            )
            setOnClickPendingIntent(
                R.id.compact_connection,
                widgetActionPendingIntent(
                    context,
                    CompactProxyWidgetProvider::class.java,
                    if (connected) ACTION_DISCONNECT else ACTION_CONNECT,
                    41000 + widgetId,
                    widgetId
                )
            )
        }
    }

    private fun bindNodeList(v: RemoteViews, context: Context, widgetId: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            bindNodeListModern(v, context)
            return
        }

        val nodeListIntent = Intent(context, NodeListWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        @Suppress("DEPRECATION")
        v.setRemoteAdapter(R.id.full_nodes_list, nodeListIntent)
    }

    @TargetApi(Build.VERSION_CODES.S)
    private fun bindNodeListModern(v: RemoteViews, context: Context) {
        val items = RemoteViews.RemoteCollectionItems.Builder()
            .setViewTypeCount(1)
        activeNodes(context).forEachIndexed { index, node ->
            val stableId = "${node.name}|${node.group}".hashCode().toLong()
            items.addItem(stableId, nodeItemView(context, index, node))
        }
        v.setRemoteAdapter(R.id.full_nodes_list, items.build())
    }

    private fun activeNodes(context: Context): List<NodeInfo> {
        if (!Prefs.isConnected(context)) return emptyList()
        return Prefs.lastSnapshot(context)
            ?.let { NodeSelector.best(it, Int.MAX_VALUE) }
            .orEmpty()
    }

    private fun nodeItemView(
        context: Context,
        index: Int,
        node: NodeInfo
    ): RemoteViews {
        val group = node.group.takeIf { it.isNotBlank() }?.let { "  ($it)" }.orEmpty()
        val text = "#${index + 1}  ${node.name}$group   ${Formatters.ping(node.pingMs)}"
        return RemoteViews(context.packageName, R.layout.widget_node_item).apply {
            setTextViewText(R.id.widget_node_item_text, text)
        }
    }

    private fun openPassWallPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, RouterLinks.passWallUri(context)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun applyFullTab(v: RemoteViews, passWallSelected: Boolean) {
        v.setViewVisibility(R.id.full_monitor_panel, if (passWallSelected) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_passwall_panel, if (passWallSelected) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.full_tab_monitor, if (passWallSelected) "Monitor" else "● Monitor")
        v.setTextViewText(R.id.full_tab_passwall2, if (passWallSelected) "● PassWall2" else "PassWall2")
        v.setTextColor(
            R.id.full_tab_monitor,
            Color.parseColor(if (passWallSelected) "#8FA7C7" else "#22D3EE")
        )
        v.setTextColor(
            R.id.full_tab_passwall2,
            Color.parseColor(if (passWallSelected) "#22D3EE" else "#8FA7C7")
        )
    }

    private fun applyFullConnectionControls(v: RemoteViews, connected: Boolean) {
        v.setTextViewText(
            R.id.full_connection_state,
            if (connected) "● Connected" else "○ Disconnected"
        )
        v.setTextColor(
            R.id.full_connection_state,
            Color.parseColor(if (connected) "#86EFAC" else "#FCA5A5")
        )
        v.setBoolean(R.id.full_connect, "setEnabled", !connected)
        v.setBoolean(R.id.full_disconnect, "setEnabled", connected)
        v.setTextColor(
            R.id.full_connect,
            Color.parseColor(if (connected) "#60738F" else "#F8FAFC")
        )
        v.setTextColor(
            R.id.full_disconnect,
            Color.parseColor(if (connected) "#F8FAFC" else "#60738F")
        )
    }

    private fun applyFullSize(v: RemoteViews, context: Context, widgetId: Int) {
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300)
            .takeIf { it > 0 } ?: 300
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 390)
            .takeIf { it > 0 } ?: 390

        val narrow = width < 240
        val short = height < 350
        val veryShort = height < 300
        val tiny = height < 310
        val ultraShort = height < 230
        val micro = height < 200

        v.setViewVisibility(R.id.full_connection_state, if (narrow) View.GONE else View.VISIBLE)
        v.setTextViewText(R.id.full_connect, if (narrow) "On" else "Connect")
        v.setTextViewText(R.id.full_disconnect, if (narrow) "Off" else "Disconnect")
        v.setTextViewText(R.id.full_refresh, if (narrow) "↻" else "↻ Refresh")

        v.setViewVisibility(R.id.full_status_row, if (short) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_profile, if (short) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_traffic, if (veryShort) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_controls_row, if (tiny) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_tabs_row, if (tiny) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_nodes_header, if (ultraShort) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_header_row, if (ultraShort) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_nodes_frame, if (micro) View.GONE else View.VISIBLE)

        v.setViewVisibility(R.id.full_passwall_profile, if (short) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_passwall_nodes, if (short) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_passwall_hint, if (short) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_passwall_title, if (veryShort) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.full_open_passwall2, if (tiny) View.GONE else View.VISIBLE)
    }

    private fun showFullLoading(context: Context, manager: AppWidgetManager, id: Int) {
        val v = fullBase(context, id)
        v.setTextViewText(R.id.full_updated, "Refreshing…")
        v.setTextViewText(R.id.full_passwall_updated, "Refreshing…")
        manager.updateAppWidget(id, v)
    }

    private fun showCompactLoading(context: Context, manager: AppWidgetManager, id: Int) {
        val v = compactBase(context, id)
        v.setTextViewText(R.id.compact_updated, "Refreshing…")
        manager.updateAppWidget(id, v)
    }

    private fun renderFull(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        s: MonitorSnapshot,
        rate: TrafficRate
    ) {
        val v = fullBase(context, id)
        val flag = Formatters.countryFlag(s.countryCode)
        val country = s.countryCode.takeIf { it.isNotBlank() }?.let { " ($it)" } ?: ""
        v.setTextViewText(R.id.full_ip, "$flag ${s.publicIp.ifBlank { "—" }}$country")

        v.setTextViewText(R.id.full_xray, "Xray ${if (s.xrayRunning) "RUNNING" else "stopped"}")
        v.setTextColor(R.id.full_xray, Color.parseColor(if (s.xrayRunning) "#86EFAC" else "#FCA5A5"))
        v.setTextViewText(R.id.full_singbox, "Sing-Box ${if (s.singboxRunning) "RUNNING" else "stopped"}")
        v.setTextColor(R.id.full_singbox, Color.parseColor(if (s.singboxRunning) "#86EFAC" else "#FCA5A5"))

        v.setTextViewText(R.id.full_profile, "🧭 ${NodeSelector.profile(s)}")
        v.setTextViewText(
            R.id.full_traffic,
            "↓ ${Formatters.rate(rate.downloadBytesPerSec)}    ↑ ${Formatters.rate(rate.uploadBytesPerSec)}"
        )

        val nodes = NodeSelector.best(s, Int.MAX_VALUE)
        v.setTextViewText(R.id.full_nodes_empty, "No live node • tap ↻")

        v.setTextViewText(R.id.full_updated, fullUpdatedLabel(context, s))
        v.setTextViewText(
            R.id.full_passwall_core,
            "Proxy core: Xray ${if (s.xrayRunning) "RUNNING" else "stopped"}"
        )
        v.setTextColor(
            R.id.full_passwall_core,
            Color.parseColor(if (s.xrayRunning) "#86EFAC" else "#FCA5A5")
        )
        v.setTextViewText(R.id.full_passwall_profile, "Active profile: ${NodeSelector.profile(s)}")
        v.setTextViewText(R.id.full_passwall_nodes, "Visible active nodes: ${nodes.size}")
        v.setTextViewText(
            R.id.full_passwall_hint,
            "Router ${RouterLinks.routerHost(context)} • LuCI login may be required"
        )
        v.setTextViewText(
            R.id.full_passwall_updated,
            fullUpdatedLabel(context, s)
        )
        manager.updateAppWidget(id, v)
    }

    private fun renderCompact(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        s: MonitorSnapshot,
        rate: TrafficRate
    ) {
        val v = compactBase(context, id)
        val flag = Formatters.countryFlag(s.countryCode)
        val country = s.countryCode.takeIf { it.isNotBlank() }?.let { " ($it)" } ?: ""
        v.setTextViewText(R.id.compact_ip, "$flag ${s.publicIp.ifBlank { "—" }}$country")
        v.setTextViewText(R.id.compact_xray, "Xray ${if (s.xrayRunning) "RUNNING" else "stopped"}")
        v.setTextColor(R.id.compact_xray, Color.parseColor(if (s.xrayRunning) "#86EFAC" else "#FCA5A5"))
        v.setTextViewText(
            R.id.compact_traffic,
            "↓ ${Formatters.rate(rate.downloadBytesPerSec)}  ↑ ${Formatters.rate(rate.uploadBytesPerSec)}"
        )

        val node = NodeSelector.best(s, 1).firstOrNull()
        v.setTextViewText(
            R.id.compact_node,
            if (node == null) "No live node • tap ↻" else formatCompactNode(node)
        )
        v.setTextViewText(R.id.compact_updated, compactUpdatedLabel(context, s))
        manager.updateAppWidget(id, v)
    }

    private fun fullUpdatedLabel(context: Context, snapshot: MonitorSnapshot): String {
        val time = Formatters.updated(snapshot.fetchedAtMs)
        return if (Prefs.lastRefreshWasIpChange(context)) {
            "IP changed • Updated $time"
        } else {
            "Updated $time"
        }
    }

    private fun compactUpdatedLabel(context: Context, snapshot: MonitorSnapshot): String {
        val time = Formatters.updated(snapshot.fetchedAtMs)
        return if (Prefs.lastRefreshWasIpChange(context)) {
            "IP ↻ $time"
        } else {
            "Updated $time"
        }
    }

    private fun formatCompactNode(node: NodeInfo): String {
        val group = node.group.takeIf { it.isNotBlank() }?.let { " ($it)" } ?: ""
        return "📡 ${node.name}$group  ${Formatters.ping(node.pingMs)}"
    }

    private fun renderFullMessage(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        heading: String,
        detail: String,
        hint: String,
        color: String
    ) {
        val v = fullBase(context, id)
        v.setTextViewText(R.id.full_ip, heading)
        v.setTextViewText(R.id.full_xray, detail)
        v.setTextColor(R.id.full_xray, Color.parseColor(color))
        v.setTextViewText(R.id.full_singbox, "")
        v.setTextViewText(R.id.full_profile, hint)
        v.setTextViewText(R.id.full_traffic, "")
        v.setViewVisibility(R.id.full_nodes_list, View.GONE)
        v.setViewVisibility(R.id.full_nodes_empty, View.VISIBLE)
        v.setTextViewText(R.id.full_nodes_empty, hint)
        v.setTextViewText(R.id.full_updated, "")
        v.setTextViewText(R.id.full_passwall_core, heading)
        v.setTextColor(R.id.full_passwall_core, Color.parseColor(color))
        v.setTextViewText(R.id.full_passwall_profile, detail)
        v.setTextViewText(R.id.full_passwall_nodes, hint)
        v.setTextViewText(
            R.id.full_passwall_hint,
            "Router ${RouterLinks.routerHost(context)} • LuCI login may be required"
        )
        v.setTextViewText(R.id.full_passwall_updated, "")
        manager.updateAppWidget(id, v)
    }

    private fun renderCompactMessage(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        heading: String,
        detail: String,
        color: String
    ) {
        val v = compactBase(context, id)
        v.setTextViewText(R.id.compact_ip, heading)
        v.setTextViewText(R.id.compact_xray, detail.take(48))
        v.setTextColor(R.id.compact_xray, Color.parseColor(color))
        v.setTextViewText(R.id.compact_traffic, "")
        v.setTextViewText(R.id.compact_node, detail)
        v.setTextViewText(R.id.compact_updated, "")
        manager.updateAppWidget(id, v)
    }
}
