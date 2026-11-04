//
//  HandTrackingPlugin.swift
//  Runner
//
//  Created by Jun Hao on 8/4/2569 BE.
//


// ios/Runner/HandTrackingPlugin.swift

import Flutter
import UIKit
import AVFoundation
import Vision

@available(iOS 14.0, *)
public class HandTrackingPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = -1
    private var latestPixelBuffer: CVPixelBuffer?

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.atomsim.session")
    private let visionQueue = DispatchQueue(label: "com.atomsim.vision")

    private var handRequest: VNDetectHumanHandPoseRequest?
    private var frameCount = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HandTrackingPlugin()
        instance.textureRegistry = registrar.textures()

        instance.methodChannel = FlutterMethodChannel(
            name: "atom_sim/hand_tracking",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = FlutterEventChannel(
            name: "atom_sim/hand_tracking/landmarks",
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
        instance.eventChannel?.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            startCamera(result: result)
        case "stop":
            stopCamera()
            result(NSNumber(value: true))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Camera

    private func startCamera(result: @escaping FlutterResult) {
        handRequest = VNDetectHumanHandPoseRequest()
        handRequest?.maximumHandCount = 2

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.sessionPreset = .hd1280x720

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input) else {
                DispatchQueue.main.async {
                    result(NSNumber(value: -1))
                }
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.visionQueue)

            guard session.canAddOutput(output) else {
                DispatchQueue.main.async { result(NSNumber(value: -1)) }
                return
            }
            session.addOutput(output)

            if let conn = output.connection(with: .video),
               conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }

            self.captureSession = session
            session.startRunning()

            DispatchQueue.main.async {
                if let reg = self.textureRegistry {
                    self.textureId = reg.register(self)
                }
                result(NSNumber(value: self.textureId))
            }
        }
    }

    private func stopCamera() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
        }
        if textureId >= 0 {
            textureRegistry?.unregisterTexture(textureId)
            textureId = -1
        }
    }

    // MARK: - Landmarks

    private static let joints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    private func toLandmarks(_ obs: VNHumanHandPoseObservation) -> NSArray {
        let pts = NSMutableArray(capacity: 21)
        for jn in HandTrackingPlugin.joints {
            if let p = try? obs.recognizedPoint(jn), p.confidence > 0.3 {
                pts.add([
                    NSNumber(value: Double(p.location.x)),
                    NSNumber(value: Double(1.0 - p.location.y)),
                    NSNumber(value: 0.0)
                ] as NSArray)
            } else {
                pts.add([
                    NSNumber(value: 0.0),
                    NSNumber(value: 0.0),
                    NSNumber(value: 0.0)
                ] as NSArray)
            }
        }
        return pts
    }

    private func send(_ observations: [VNHumanHandPoseObservation]) {
        let arr = NSMutableArray()
        for obs in observations {
            let lm = toLandmarks(obs)

            var left = false
            if #available(iOS 15.0, *) {
                left = obs.chirality == .left
            }

            arr.add([
                "landmarks": lm,
                "isLeft": NSNumber(value: left)
            ] as NSDictionary)
        }

        let payload: NSDictionary = ["hands": arr]
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }

    private func sendNone() {
        let payload: NSDictionary = ["hands": NSArray()]
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }
}

// MARK: - AVCapture delegate

@available(iOS 14.0, *)
extension HandTrackingPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sb: CMSampleBuffer,
                              from conn: AVCaptureConnection) {
        guard let buf = CMSampleBufferGetImageBuffer(sb) else { return }

        // Feed Flutter texture
        latestPixelBuffer = buf
        DispatchQueue.main.async { [weak self] in
            guard let s = self, s.textureId >= 0 else { return }
            s.textureRegistry?.textureFrameAvailable(s.textureId)
        }

        // Hand detection every 3rd frame
        frameCount += 1
        guard frameCount % 3 == 0, let req = handRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)
        do {
            try handler.perform([req])
            if let r = req.results, !r.isEmpty { send(r) }
            else { sendNone() }
        } catch {
            sendNone()
        }
    }
}

// MARK: - Flutter Texture

@available(iOS 14.0, *)
extension HandTrackingPlugin: FlutterTexture {
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buf = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buf)
    }
}