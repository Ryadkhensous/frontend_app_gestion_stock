package com.stockapp.frontend

import android.content.Context
import android.hardware.input.InputManager
import android.os.Build
import android.view.InputDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.stockapp/scanner_status"
    private val EVENT_CHANNEL = "com.stockapp/scanner_events"

    private var eventSink: EventChannel.EventSink? = null
    private var inputManager: InputManager? = null

    private val inputDeviceListener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) {
            notifyScannerStatus()
        }

        override fun onInputDeviceRemoved(deviceId: Int) {
            notifyScannerStatus()
        }

        override fun onInputDeviceChanged(deviceId: Int) {
            notifyScannerStatus()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        inputManager = getSystemService(Context.INPUT_SERVICE) as? InputManager
        inputManager?.registerInputDeviceListener(inputDeviceListener, null)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getScannerStatus") {
                result.success(getScannerDetails())
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                notifyScannerStatus()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        inputManager?.unregisterInputDeviceListener(inputDeviceListener)
    }

    private fun isExternalScannerOrKeyboard(device: InputDevice): Boolean {
        if (device.isVirtual) return false
        val sources = device.sources
        val isKeyboard = (sources and InputDevice.SOURCE_KEYBOARD) == InputDevice.SOURCE_KEYBOARD
        if (!isKeyboard) return false

        // In Android 10 (API 29) and above, device.isExternal indicates Bluetooth or USB physical device
        val isExternal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            device.isExternal
        } else {
            // Devices with id > 0 and non-virtual keyboard
            !device.isVirtual && device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC
        }

        val isAlphabetic = device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC
        return isExternal && isAlphabetic
    }

    private fun getScannerDetails(): Map<String, Any?> {
        val im = inputManager ?: return mapOf("connected" to false, "deviceName" to "")
        val deviceIds = im.inputDeviceIds ?: IntArray(0)

        for (id in deviceIds) {
            val device = im.getInputDevice(id)
            if (device != null && isExternalScannerOrKeyboard(device)) {
                return mapOf(
                    "connected" to true,
                    "deviceName" to (device.name ?: "Douchette Code-Barres"),
                    "productId" to device.productId,
                    "vendorId" to device.vendorId
                )
            }
        }
        return mapOf("connected" to false, "deviceName" to "")
    }

    private fun notifyScannerStatus() {
        val details = getScannerDetails()
        runOnUiThread {
            eventSink?.success(details)
        }
    }
}
