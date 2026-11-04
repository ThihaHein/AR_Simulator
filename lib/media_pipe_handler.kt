-----------------------------------------------------------------

package com.example.atom_sim_3d

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.framework.image.BitmapImageBuilder
import org.json.JSONArray
import org.json.JSONObject

class MediaPipePlugin : FlutterPlugin {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var handLandmarker: HandLandmarker? = null
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var cameraDevice: CameraDevice? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "atom_sim/mediapipe")
        eventChannel = EventChannel(binding.binaryMessenger, "atom_sim/mediapipe/landmarks")

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    val success = initHandLandmarker(context)
                    if (success) startCamera(context)
                    result.success(success)
                }
                "stopTracking" -> {
                    stopCamera()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun initHandLandmarker(context: Context): Boolean {
        return try {
            val options = HandLandmarkerOptions.builder()
                .setBaseOptions(
                    com.google.mediapipe.tasks.core.BaseOptions.builder()
                        .setModelAssetPath("hand_landmarker.task")
                        .build()
                )
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener { result, input ->
                    val json = JSONObject()
                    val handsArray = JSONArray()

                    for (i in result.landmarks().indices) {
                        val handJson = JSONObject()
                        val lmArray = JSONArray()

                        for (lm in result.landmarks()[i]) {
                            val point = JSONArray()
                            point.put(lm.x().toDouble())
                            point.put(lm.y().toDouble())
                            point.put(lm.z().toDouble())
                            lmArray.put(point)
                        }

                        handJson.put("landmarks", lmArray)
                        handJson.put("isLeft",
                            result.handedness()[i][0].categoryName() == "Left")
                        handsArray.put(handJson)
                    }

                    json.put("hands", handsArray)

                    // Send to Flutter on main thread
                    Handler(android.os.Looper.getMainLooper()).post {
                        eventSink?.success(json.toString())
                    }
                }
                .build()

            handLandmarker = HandLandmarker.createFromOptions(context, options)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun startCamera(context: Context) {
        cameraThread = HandlerThread("CameraThread").also { it.start() }
        cameraHandler = Handler(cameraThread!!.looper)

        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
            val characteristics = cameraManager.getCameraCharacteristics(id)
            characteristics.get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_FRONT
        } ?: return

        try {
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    // Camera frame processing would connect here.
                    // Each frame → convert to MPImage → handLandmarker.detectAsync()
                }
                override fun onDisconnected(camera: CameraDevice) { camera.close() }
                override fun onError(camera: CameraDevice, error: Int) { camera.close() }
            }, cameraHandler)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun stopCamera() {
        cameraDevice?.close()
        cameraDevice = null
        cameraThread?.quitSafely()
        handLandmarker?.close()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        stopCamera()
    }
}