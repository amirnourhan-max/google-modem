package com.amirnourhan.proxymonitor

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.Switch
import android.widget.TextView
import java.net.URL

class MainActivity : Activity() {
    companion object {
        private const val REQUEST_NOTIFICATIONS = 2401
    }

    private var receiverRegistered = false
    private var pendingConnect = false

    private lateinit var urlInput: EditText
    private lateinit var messageText: TextView
    private lateinit var countdownText: TextView
    private lateinit var ipText: TextView
    private lateinit var statusText: TextView
    private lateinit var profileText: TextView
    private lateinit var downloadText: TextView
    private lateinit var uploadText: TextView
    private lateinit var nodesText: TextView
    private lateinit var connectButton: Button
    private lateinit var disconnectButton: Button
    private lateinit var appTabMonitor: TextView
    private lateinit var appTabPasswall2: TextView
    private lateinit var appMonitorPanel: View
    private lateinit var appPasswallPanel: View
    private lateinit var appPasswallCore: TextView
    private lateinit var appPasswallProfile: TextView
    private lateinit var appPasswallNodes: TextView
    private lateinit var autoIpSwitch: Switch
    private lateinit var autoIpStatus: TextView

    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            renderStoredState()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        urlInput = findViewById(R.id.urlInput)
        messageText = findViewById(R.id.messageText)
        countdownText = findViewById(R.id.countdownText)
        ipText = findViewById(R.id.ipText)
        statusText = findViewById(R.id.statusText)
        profileText = findViewById(R.id.profileText)
        downloadText = findViewById(R.id.downloadText)
        uploadText = findViewById(R.id.uploadText)
        nodesText = findViewById(R.id.nodesText)
        connectButton = findViewById(R.id.connectButton)
        disconnectButton = findViewById(R.id.disconnectButton)
        appTabMonitor = findViewById(R.id.appTabMonitor)
        appTabPasswall2 = findViewById(R.id.appTabPasswall2)
        appMonitorPanel = findViewById(R.id.appMonitorPanel)
        appPasswallPanel = findViewById(R.id.appPasswallPanel)
        appPasswallCore = findViewById(R.id.appPasswallCore)
        appPasswallProfile = findViewById(R.id.appPasswallProfile)
        appPasswallNodes = findViewById(R.id.appPasswallNodes)
        autoIpSwitch = findViewById(R.id.autoIpSwitch)
        autoIpStatus = findViewById(R.id.autoIpStatus)

        urlInput.setText(Prefs.url(this))
        autoIpSwitch.isChecked = Prefs.autoIpRefresh(this)
        updateAutoIpUi()
        showAppTab(Prefs.appTab(this) == "passwall2", persist = false)

        appTabMonitor.setOnClickListener { showAppTab(passWallSelected = false) }
        appTabPasswall2.setOnClickListener { showAppTab(passWallSelected = true) }
        findViewById<Button>(R.id.appOpenPasswall2).setOnClickListener {
            runCatching {
                startActivity(Intent(Intent.ACTION_VIEW, RouterLinks.passWallUri(this)))
            }.onFailure { showError("Could not open PassWall2 panel") }
        }
        autoIpSwitch.setOnCheckedChangeListener { _, enabled ->
            Prefs.setAutoIpRefresh(this, enabled)
            updateAutoIpUi()
            if (enabled && Prefs.isConnected(this)) {
                runCatching { PersistentConnectionService.requestIpCheck(this) }
            }
            renderStoredState()
        }

        findViewById<Button>(R.id.refreshButton).setOnClickListener {
            if (!Prefs.isConnected(this)) {
                showError("Connect first")
                return@setOnClickListener
            }

            messageText.setTextColor(Color.parseColor("#9DB0C9"))
            messageText.text = "Refreshing once… connection stays active"
            runCatching { PersistentConnectionService.requestRefresh(this) }
                .onFailure { showError(it.message ?: "Refresh failed") }
        }

        connectButton.setOnClickListener { beginConnect() }

        disconnectButton.setOnClickListener {
            PersistentConnectionService.disconnect(this)
            renderStoredState()
        }
    }

    override fun onStart() {
        super.onStart()
        registerStateReceiver()
        if (Prefs.isConnected(this)) {
            runCatching { PersistentConnectionService.ensureRunning(this) }
        }
        renderStoredState()
    }

    override fun onStop() {
        if (receiverRegistered) {
            unregisterReceiver(stateReceiver)
            receiverRegistered = false
        }
        super.onStop()
    }

    private fun registerStateReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(PersistentConnectionService.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(stateReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun beginConnect() {
        val url = validatedUrl() ?: return
        Prefs.save(this, url)
        Prefs.clearLastError(this)

        if (!PersistentConnectionService.isWifiConnected(this)) {
            Prefs.setDisconnectReason(this, "Wi-Fi is off • turn it on, then tap Connect")
            renderStoredState()
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingConnect = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
            return
        }

        startPersistentConnection()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS && pendingConnect) {
            pendingConnect = false
            startPersistentConnection()
        }
    }

    private fun startPersistentConnection() {
        runCatching { PersistentConnectionService.connect(this) }
            .onSuccess {
                renderStoredState()
                messageText.setTextColor(Color.parseColor("#86EFAC"))
                messageText.text = if (Prefs.autoIpRefresh(this)) {
                    "Connected • auto-refreshes only when Public IP changes"
                } else {
                    "Connected • refresh is manual only"
                }
            }
            .onFailure { showError(it.message ?: "Could not start connection") }
    }

    private fun validatedUrl(): String? {
        val raw = urlInput.text.toString().trim()
        val valid = runCatching {
            val url = URL(raw)
            (url.protocol == "http" || url.protocol == "https") && url.host.isNotBlank()
        }.getOrDefault(false)

        if (!valid) {
            showError("Enter a valid http:// or https:// router URL")
            return null
        }
        return raw
    }

    private fun renderStoredState() {
        val connected = Prefs.isConnected(this)
        val snapshot = Prefs.lastSnapshot(this)
        if (snapshot != null) {
            render(snapshot, Prefs.lastRate(this))
        } else {
            appPasswallCore.text = if (connected) "Router connection: Connected" else "Router connection: Disconnected"
            appPasswallCore.setTextColor(Color.parseColor(if (connected) "#86EFAC" else "#FCA5A5"))
            appPasswallProfile.text = "Active profile: —"
            appPasswallNodes.text = "Visible active nodes: —"
        }
        updateAutoIpUi()

        connectButton.isEnabled = !connected
        connectButton.alpha = if (connected) 0.45f else 1f
        disconnectButton.isEnabled = connected
        disconnectButton.alpha = if (connected) 1f else 0.45f
        urlInput.isEnabled = !connected

        if (!connected) {
            countdownText.text = "Disconnected"
            val reason = Prefs.disconnectReason(this)
            messageText.setTextColor(
                Color.parseColor(if (reason.startsWith("Wi-Fi")) "#FCA5A5" else "#9DB0C9")
            )
            messageText.text = reason.ifBlank { "Tap Connect to keep the connection active" }
            return
        }

        countdownText.text = if (Prefs.autoIpRefresh(this)) {
            "Connected • refresh on IP change"
        } else {
            "Connected • manual refresh only"
        }
        val error = Prefs.lastError(this)
        val refreshNotice = Prefs.refreshNotice(this)
        if (error.isNotBlank()) {
            messageText.setTextColor(Color.parseColor("#FCD34D"))
            messageText.text = "Refresh failed • still connected • ${error.take(140)}"
        } else if (refreshNotice.isNotBlank()) {
            messageText.setTextColor(Color.parseColor("#22D3EE"))
            messageText.text = refreshNotice
        } else if (snapshot != null && snapshot.fetchedAtMs > 0L) {
            messageText.setTextColor(Color.parseColor("#86EFAC"))
            messageText.text = "Connected • last refresh ${Formatters.updated(snapshot.fetchedAtMs)}"
        } else {
            messageText.setTextColor(Color.parseColor("#86EFAC"))
            messageText.text = "Connected • tap Refresh when needed"
        }
    }

    private fun showError(message: String) {
        messageText.setTextColor(Color.parseColor("#FCA5A5"))
        messageText.text = message
    }

    private fun showAppTab(passWallSelected: Boolean, persist: Boolean = true) {
        appMonitorPanel.visibility = if (passWallSelected) View.GONE else View.VISIBLE
        appPasswallPanel.visibility = if (passWallSelected) View.VISIBLE else View.GONE
        appTabMonitor.text = if (passWallSelected) "Monitor" else "● Monitor"
        appTabPasswall2.text = if (passWallSelected) "● PassWall2" else "PassWall2"
        appTabMonitor.setTextColor(Color.parseColor(if (passWallSelected) "#8FA7C7" else "#22D3EE"))
        appTabPasswall2.setTextColor(Color.parseColor(if (passWallSelected) "#22D3EE" else "#8FA7C7"))
        if (persist) {
            Prefs.setAppTab(this, if (passWallSelected) "passwall2" else "monitor")
        }
    }

    private fun updateAutoIpUi() {
        autoIpStatus.text = if (Prefs.autoIpRefresh(this)) {
            "On • checks IP every 30s • full refresh only after a change"
        } else {
            "Off • all refreshes are manual"
        }
        autoIpStatus.setTextColor(
            Color.parseColor(if (Prefs.autoIpRefresh(this)) "#86EFAC" else "#8FA7C7")
        )
    }

    private fun render(s: MonitorSnapshot, rate: TrafficRate) {
        val flag = Formatters.countryFlag(s.countryCode)
        val country = s.countryCode.takeIf { it.isNotBlank() }?.let { "($it)" }.orEmpty()
        ipText.text = "$flag Public IP: ${s.publicIp.ifBlank { "—" }} $country"
        statusText.text = "Xray ${if (s.xrayRunning) "RUNNING" else "stopped"}  •  Sing-Box ${if (s.singboxRunning) "RUNNING" else "stopped"}"
        statusText.setTextColor(Color.parseColor(if (s.xrayRunning) "#86EFAC" else "#FCA5A5"))
        profileText.text = "Profile: ${NodeSelector.profile(s)}"
        downloadText.text = Formatters.rate(rate.downloadBytesPerSec)
        uploadText.text = Formatters.rate(rate.uploadBytesPerSec)

        val nodes = NodeSelector.best(s)
        appPasswallCore.text = "Proxy core: Xray ${if (s.xrayRunning) "RUNNING" else "stopped"}"
        appPasswallCore.setTextColor(Color.parseColor(if (s.xrayRunning) "#86EFAC" else "#FCA5A5"))
        appPasswallProfile.text = "Active profile: ${NodeSelector.profile(s)}"
        appPasswallNodes.text = "Visible active nodes: ${nodes.size}"
        nodesText.text = if (nodes.isEmpty()) {
            "No live node detected. Open a proxied site and refresh."
        } else {
            nodes.mapIndexed { index, node ->
                val group = node.group.takeIf { it.isNotBlank() }?.let { "  ($it)" }.orEmpty()
                "#${index + 1}  ${node.name}$group   ${Formatters.ping(node.pingMs)}"
            }.joinToString("\n")
        }
    }
}
