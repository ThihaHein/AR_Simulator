// macos/Runner/AppDelegate.swift
import Cocoa
import FlutterMacOS
import AVFoundation
import Vision
import CoreML

@main
class AppDelegate: FlutterAppDelegate {
    private var handSink: FlutterEventSink?
    private var objectSink: FlutterEventSink?
    private var handReady = false, objectReady = false
    private var captureSession: AVCaptureSession?
    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = -1
    private var textureBridge: CameraTextureBridge?
    private let cameraQueue = DispatchQueue(label: "com.atomsim.camera")
    private var frameCount = 0
    private var objectDetectionRequest: VNCoreMLRequest?

    @available(macOS 11.0, *)
    private lazy var handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest(); r.maximumHandCount = 2; return r
    }()

    private let joints: [VNHumanHandPoseObservation.JointName] = [
        .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    override func applicationDidFinishLaunching(_ n: Notification) {
        let c = mainFlutterWindow?.contentViewController as! FlutterViewController
        let m = c.engine.binaryMessenger
        textureRegistry = c.engine.registrar(forPlugin: "Cam").textures

        FlutterMethodChannel(name: "atom_sim/native_camera", binaryMessenger: m)
            .setMethodCallHandler { [weak self] call, res in
                switch call.method {
                case "start": res(NSNumber(value: self?.startCamera() ?? -1))
                case "stop": self?.stopCamera(); res(nil)
                default: res(FlutterMethodNotImplemented)
                }
            }
        FlutterMethodChannel(name: "atom_sim/hand_tracking", binaryMessenger: m)
            .setMethodCallHandler { [weak self] call, res in
                switch call.method {
                case "init":
                    if #available(macOS 11.0, *) { self?.handReady = true; res(true) } else { res(false) }
                case "processFrame": res(nil)
                case "dispose": self?.handReady = false; res(nil)
                default: res(FlutterMethodNotImplemented)
                }
            }
        FlutterEventChannel(name: "atom_sim/hand_tracking/results", binaryMessenger: m)
            .setStreamHandler(Sink { [weak self] s in self?.handSink = s })
        FlutterMethodChannel(name: "atom_sim/object_detection", binaryMessenger: m)
            .setMethodCallHandler { [weak self] call, res in
                switch call.method {
                case "init": self?.initYOLO(); self?.objectReady = true; res(true)
                case "dispose": self?.objectReady = false; res(nil)
                default: res(FlutterMethodNotImplemented)
                }
            }
        FlutterEventChannel(name: "atom_sim/object_detection/results", binaryMessenger: m)
            .setStreamHandler(Sink { [weak self] s in self?.objectSink = s })
        super.applicationDidFinishLaunching(n)
    }

    private func initYOLO() {
        for name in ["YOLOv3","YOLOv3FP16","YOLOv3Int8LUT","YOLOv8s","YOLOv8n","YOLOv3Tiny","YOLOv3TinyInt8LUT"] {
            if let u = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
               let md = try? VNCoreMLModel(for: MLModel(contentsOf: u)) {
                let r = VNCoreMLRequest(model: md); r.imageCropAndScaleOption = .scaleFill
                objectDetectionRequest = r; return
            }
            if let u = Bundle.main.url(forResource: name, withExtension: "mlmodel"),
               let c = try? MLModel.compileModel(at: u), let ml = try? MLModel(contentsOf: c),
               let vn = try? VNCoreMLModel(for: ml) {
                let r = VNCoreMLRequest(model: vn); r.imageCropAndScaleOption = .scaleFill
                objectDetectionRequest = r; return
            }
        }
    }

    private func startCamera() -> Int64 {
        let s = AVCaptureSession(); s.sessionPreset = .medium
        guard let d = AVCaptureDevice.default(for: .video),
              let i = try? AVCaptureDeviceInput(device: d), s.canAddInput(i) else { return -1 }
        s.addInput(i)
        let o = AVCaptureVideoDataOutput()
        o.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        o.alwaysDiscardsLateVideoFrames = true
        o.setSampleBufferDelegate(self, queue: cameraQueue)
        guard s.canAddOutput(o) else { return -1 }
        s.addOutput(o)
        let b = CameraTextureBridge()
        textureId = textureRegistry?.register(b) ?? -1; textureBridge = b
        captureSession = s; s.startRunning(); return textureId
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        if textureId >= 0 { textureRegistry?.unregisterTexture(textureId); textureId = -1 }
    }

    @available(macOS 11.0, *)
    private func doHands(_ buf: CVPixelBuffer) {
        let h = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)
        guard let _ = try? h.perform([handRequest]) else { emit(handSink, "hands", []); return }
        var a: [[String:Any]] = []
        for o in (handRequest.results ?? []) {
            var lm: [[NSNumber]] = []
            for j in joints {
                if let p = try? o.recognizedPoint(j), p.confidence > 0.3 {
                    lm.append([NSNumber(value:Float(p.location.x)),NSNumber(value:Float(1-p.location.y)),NSNumber(value:0)])
                } else { lm.append([NSNumber(value:0),NSNumber(value:0),NSNumber(value:0)]) }
            }
            var l = false; if #available(macOS 12.0, *) { l = o.chirality == .left }
            a.append(["landmarks":lm as NSArray,"isLeft":NSNumber(value:l)])
        }
        emit(handSink, "hands", a)
    }

    private func doObjects(_ buf: CVPixelBuffer) {
        if let req = objectDetectionRequest {
            let h = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)
            guard let _ = try? h.perform([req]) else { emit(objectSink,"objects",[]); return }
            var o: [[String:Any]] = []
            for obs in (req.results ?? []) {
                if let d = obs as? VNRecognizedObjectObservation, let t = d.labels.first, t.confidence > 0.3 {
                    let b = d.boundingBox
                    o.append(["label":t.identifier as NSString,"confidence":NSNumber(value:t.confidence),
                              "x":NSNumber(value:Float(b.origin.x)),"y":NSNumber(value:Float(1-b.origin.y-b.height)),
                              "w":NSNumber(value:Float(b.width)),"h":NSNumber(value:Float(b.height))])
                }
            }
            emit(objectSink, "objects", o)
        } else { fallbackDetect(buf) }
    }

    private func fallbackDetect(_ buf: CVPixelBuffer) {
        guard #available(macOS 11.0, *) else { return }
        let h = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)
        let rr = VNDetectRectanglesRequest(); rr.maximumObservations = 5; rr.minimumConfidence = 0.6
        let cr = VNClassifyImageRequest()
        guard let _ = try? h.perform([rr, cr]) else { emit(objectSink,"objects",[]); return }
        var tl = "object"; var tc: Float = 0.5
        for c in (cr.results ?? []).prefix(3) where c.confidence > 0.3 { tl = c.identifier; tc = c.confidence; break }
        var o: [[String:Any]] = []
        for r in (rr.results ?? []) {
            let b = r.boundingBox
            o.append(["label":tl as NSString,"confidence":NSNumber(value:max(r.confidence,tc)),
                       "x":NSNumber(value:Float(b.origin.x)),"y":NSNumber(value:Float(1-b.origin.y-b.height)),
                       "w":NSNumber(value:Float(b.width)),"h":NSNumber(value:Float(b.height))])
        }
        emit(objectSink, "objects", o)
    }

    private func emit(_ sink: FlutterEventSink?, _ key: String, _ arr: [[String:Any]]) {
        let p: NSDictionary = [key: arr as NSArray]
        let s = sink; DispatchQueue.main.async { s?(p) }
    }
}

extension AppDelegate: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ o: AVCaptureOutput, didOutput sb: CMSampleBuffer, from c: AVCaptureConnection) {
        guard let buf = CMSampleBufferGetImageBuffer(sb) else { return }
        textureBridge?.latestBuffer = buf
        if textureId >= 0 { DispatchQueue.main.async { [weak self] in self?.textureRegistry?.textureFrameAvailable(self?.textureId ?? -1) } }
        frameCount += 1
        if frameCount % 3 == 0 && handReady { if #available(macOS 11.0, *) { doHands(buf) } }
        if frameCount % 5 == 0 && objectReady { doObjects(buf) }
    }
}

class Sink: NSObject, FlutterStreamHandler {
    let cb: (FlutterEventSink?) -> Void
    init(_ cb: @escaping (FlutterEventSink?) -> Void) { self.cb = cb }
    func onListen(withArguments a: Any?, eventSink e: @escaping FlutterEventSink) -> FlutterError? { cb(e); return nil }
    func onCancel(withArguments a: Any?) -> FlutterError? { cb(nil); return nil }
}

class CameraTextureBridge: NSObject, FlutterTexture {
    var latestBuffer: CVPixelBuffer?
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? { guard let b = latestBuffer else { return nil }; return Unmanaged.passRetained(b) }
}
