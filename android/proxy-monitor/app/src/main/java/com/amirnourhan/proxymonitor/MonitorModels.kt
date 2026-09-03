package com.amirnourhan.proxymonitor

data class NodeInfo(
    val name: String,
    val group: String,
    val pingMs: Double?
)

data class MonitorSnapshot(
    val publicIp: String,
    val countryCode: String,
    val xrayRunning: Boolean,
    val singboxRunning: Boolean,
    val selectedRemark: String,
    val selectedType: String,
    val selectedProtocol: String,
    val expectedNodes: Int,
    val nodes: List<NodeInfo>,
    val device: String,
    val rxBytes: Long,
    val txBytes: Long,
    val fetchedAtMs: Long
)

data class TrafficRate(
    val downloadBytesPerSec: Double,
    val uploadBytesPerSec: Double
)
