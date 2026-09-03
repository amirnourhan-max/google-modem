package com.amirnourhan.proxymonitor

object NodeSelector {
    fun best(snapshot: MonitorSnapshot, maxCount: Int = 5): List<NodeInfo> {
        val expectedLimit = snapshot.expectedNodes
            .takeIf { it > 0 }
            ?: Int.MAX_VALUE
        val effectiveLimit = minOf(maxCount.coerceAtLeast(0), expectedLimit)

        return snapshot.nodes
            .filter { it.name.isNotBlank() }
            .distinctBy { it.name + "|" + it.group }
            .sortedWith(compareBy<NodeInfo> { it.pingMs == null }.thenBy { it.pingMs ?: Double.MAX_VALUE })
            .take(effectiveLimit)
    }

    fun profile(snapshot: MonitorSnapshot): String {
        return listOf(snapshot.selectedRemark, snapshot.selectedType, snapshot.selectedProtocol)
            .filter { it.isNotBlank() }
            .joinToString(" — ")
            .ifBlank { "—" }
    }
}
