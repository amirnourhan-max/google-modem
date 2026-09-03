package com.amirnourhan.proxymonitor

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class NodeListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        NodeListFactory(applicationContext)

    private class NodeListFactory(
        private val context: Context
    ) : RemoteViewsFactory {
        private var nodes: List<NodeInfo> = emptyList()

        override fun onCreate() = reload()

        override fun onDataSetChanged() = reload()

        override fun onDestroy() {
            nodes = emptyList()
        }

        override fun getCount(): Int = nodes.size

        override fun getViewAt(position: Int): RemoteViews {
            val node = nodes.getOrNull(position)
            val text = if (node == null) {
                ""
            } else {
                val group = node.group.takeIf { it.isNotBlank() }?.let { "  ($it)" }.orEmpty()
                "#${position + 1}  ${node.name}$group   ${Formatters.ping(node.pingMs)}"
            }
            return RemoteViews(context.packageName, R.layout.widget_node_item).apply {
                setTextViewText(R.id.widget_node_item_text, text)
            }
        }

        override fun getLoadingView(): RemoteViews? = null

        override fun getViewTypeCount(): Int = 1

        override fun getItemId(position: Int): Long =
            nodes.getOrNull(position)
                ?.let { "${it.name}|${it.group}".hashCode().toLong() }
                ?: position.toLong()

        override fun hasStableIds(): Boolean = true

        private fun reload() {
            nodes = if (Prefs.isConnected(context)) {
                Prefs.lastSnapshot(context)
                    ?.let { NodeSelector.best(it, Int.MAX_VALUE) }
                    .orEmpty()
            } else {
                emptyList()
            }
        }
    }
}
