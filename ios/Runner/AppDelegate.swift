// ios/Runner/AppDelegate.swift

import Flutter
import UIKit
import AVFoundation
import Vision
import CoreML

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var handSink: FlutterEventSink?
    private var objectSink: FlutterEventSink?
    private var handReady = false
    private var objectReady = false

    private var captureSession: AVCaptureSession?
    private var textureRegistry: FlutterTextureRegistry?
    private var textureId: Int64 = -1
    private var textureBridge: CameraTextureBridge?
    private let cameraQueue = DispatchQueue(label: "com.atomsim.camera")
    private let visionQueue = DispatchQueue(label: "com.atomsim.vision", qos: .userInteractive)
    private var frameCount = 0

    // CoreML object detection
    private var objectDetectionRequest: VNCoreMLRequest?

    @available(iOS 14.0, *)
    private lazy var handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()

    private let joints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let registrar = self.registrar(forPlugin: "AtomSimPlugins")!
        let messenger = registrar.messenger()
        textureRegistry = registrar.textures()

        // Native camera
        FlutterMethodChannel(name: "atom_sim/native_camera", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "start": result(NSNumber(value: self?.startCamera() ?? -1))
                case "stop": self?.stopCamera(); result(nil)
                default: result(FlutterMethodNotImplemented)
                }
            }

        // Hand tracking
        FlutterMethodChannel(name: "atom_sim/hand_tracking", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "init":
                    if #available(iOS 14.0, *) { self?.handReady = true; result(true) }
                    else { result(false) }
                case "processFrame": result(nil)
                case "dispose": self?.handReady = false; result(nil)
                default: result(FlutterMethodNotImplemented)
                }
            }
        FlutterEventChannel(name: "atom_sim/hand_tracking/results", binaryMessenger: messenger)
            .setStreamHandler(SinkHandler { [weak self] s in self?.handSink = s })

        // Object detection
        FlutterMethodChannel(name: "atom_sim/object_detection", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "init":
                    self?.initObjectDetection()
                    self?.objectReady = true
                    result(true)
                case "dispose":
                    self?.objectReady = false
                    result(nil)
                default: result(FlutterMethodNotImplemented)
                }
            }
        FlutterEventChannel(name: "atom_sim/object_detection/results", binaryMessenger: messenger)
            .setStreamHandler(SinkHandler { [weak self] s in self?.objectSink = s })

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Object Detection Init (CoreML)

    private func initObjectDetection() {
        // Prefer larger, more accurate models first
        let modelNames = [
            "YOLOv3",              // Full — most accurate (248MB)
            "YOLOv3FP16",         // Full half-precision
            "YOLOv3Int8LUT",      // Full quantized
            "YOLOv8s",            // YOLOv8 small (if user converted one)
            "YOLOv8n",            // YOLOv8 nano
            "YOLOv3Tiny",         // Tiny — fast but less accurate
            "YOLOv3TinyInt8LUT",  // Tiny quantized — fastest
        ]

        for name in modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
               let model = try? VNCoreMLModel(for: MLModel(contentsOf: url)) {
                let request = VNCoreMLRequest(model: model)
                request.imageCropAndScaleOption = .scaleFill
                objectDetectionRequest = request
                print("Loaded CoreML model: \(name)")
                return
            }
        }

        // Fallback: try compiled model
        for name in modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodel") {
                if let compiled = try? MLModel.compileModel(at: url),
                   let mlModel = try? MLModel(contentsOf: compiled),
                   let vnModel = try? VNCoreMLModel(for: mlModel) {
                    let request = VNCoreMLRequest(model: vnModel)
                    request.imageCropAndScaleOption = .scaleFill
                    objectDetectionRequest = request
                    print("Compiled and loaded CoreML model: \(name)")
                    return
                }
            }
        }

        print("No YOLO model found — download YOLOv3TinyInt8LUT.mlmodel from Apple")
    }

    // MARK: - Camera

    private func startCamera() -> Int64 {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Use back camera for object detection (more useful than front)
        let position: AVCaptureDevice.Position = .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return -1 }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: cameraQueue)
        guard session.canAddOutput(output) else { return -1 }
        session.addOutput(output)

        if let c = output.connection(with: .video) {
            if c.isVideoOrientationSupported { c.videoOrientation = .portrait }
        }

        let bridge = CameraTextureBridge()
        textureId = textureRegistry?.register(bridge) ?? -1
        textureBridge = bridge
        captureSession = session
        session.startRunning()
        return textureId
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
        if textureId >= 0 { textureRegistry?.unregisterTexture(textureId); textureId = -1 }
    }

    // MARK: - Hand processing

    @available(iOS 14.0, *)
    private func processHands(_ buf: CVPixelBuffer) {
        let h = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)
        guard let _ = try? h.perform([handRequest]) else {
            sendEmpty(sink: handSink, key: "hands"); return
        }
        var arr: [[String: Any]] = []
        for o in (handRequest.results ?? []) {
            var lm: [[NSNumber]] = []
            for jn in joints {
                if let pt = try? o.recognizedPoint(jn), pt.confidence > 0.3 {
                    lm.append([NSNumber(value: Float(pt.location.x)),
                               NSNumber(value: Float(1.0 - pt.location.y)),
                               NSNumber(value: 0.0)])
                } else {
                    lm.append([NSNumber(value: 0.0), NSNumber(value: 0.0), NSNumber(value: 0.0)])
                }
            }
            var isLeft = false
            if #available(iOS 15.0, *) { isLeft = o.chirality == .left }
            arr.append(["landmarks": lm as NSArray, "isLeft": NSNumber(value: isLeft)])
        }
        let p: NSDictionary = ["hands": arr as NSArray]
        DispatchQueue.main.async { [weak self] in self?.handSink?(p) }
    }

    // MARK: - Object detection (CoreML YOLO)

    private func processObjects(_ buf: CVPixelBuffer) {
        guard let request = objectDetectionRequest else {
            // No model loaded — fall back to basic Vision
            processObjectsFallback(buf)
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)
        do {
            try handler.perform([request])

            var objects: [[String: Any]] = []

            if let results = request.results {
                for observation in results {
                    if let detected = observation as? VNRecognizedObjectObservation {
                        let box = detected.boundingBox
                        let topLabel = detected.labels.first

                        guard let label = topLabel, label.confidence > 0.3 else { continue }

                        objects.append([
                            "label": label.identifier as NSString,
                            "confidence": NSNumber(value: label.confidence),
                            "x": NSNumber(value: Float(box.origin.x)),
                            "y": NSNumber(value: Float(1.0 - box.origin.y - box.height)),
                            "w": NSNumber(value: Float(box.width)),
                            "h": NSNumber(value: Float(box.height)),
                        ])
                    }
                }
            }

            let payload: NSDictionary = ["objects": objects as NSArray]
            DispatchQueue.main.async { [weak self] in self?.objectSink?(payload) }

        } catch {
            sendEmpty(sink: objectSink, key: "objects")
        }
    }

    // Fallback without CoreML model
    private func processObjectsFallback(_ buf: CVPixelBuffer) {
        guard #available(iOS 14.0, *) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .up)

        // Use multiple built-in detectors
        var requests: [VNRequest] = []

        // Detect human bodies
        let bodyReq = VNDetectHumanRectanglesRequest()
        requests.append(bodyReq)

        // Detect animals
        let animalReq = VNRecognizeAnimalsRequest()
        requests.append(animalReq)

        // Detect text (indicates screens, signs, books)
        let textReq = VNDetectTextRectanglesRequest()
        requests.append(textReq)

        do {
            try handler.perform(requests)

            var objects: [[String: Any]] = []

            // Humans
            if let bodies = bodyReq.results {
                for body in bodies where body.confidence > 0.5 {
                    let b = body.boundingBox
                    objects.append([
                        "label": "person" as NSString,
                        "confidence": NSNumber(value: body.confidence),
                        "x": NSNumber(value: Float(b.origin.x)),
                        "y": NSNumber(value: Float(1.0 - b.origin.y - b.height)),
                        "w": NSNumber(value: Float(b.width)),
                        "h": NSNumber(value: Float(b.height)),
                    ])
                }
            }

            // Animals
            if let animals = animalReq.results {
                for animal in animals {
                    let topLabel = animal.labels.first
                    guard let label = topLabel, label.confidence > 0.4 else { continue }
                    let b = animal.boundingBox
                    objects.append([
                        "label": label.identifier as NSString,
                        "confidence": NSNumber(value: label.confidence),
                        "x": NSNumber(value: Float(b.origin.x)),
                        "y": NSNumber(value: Float(1.0 - b.origin.y - b.height)),
                        "w": NSNumber(value: Float(b.width)),
                        "h": NSNumber(value: Float(b.height)),
                    ])
                }
            }

            // Text regions → label as "screen" or "book"
            if let texts = textReq.results {
                for text in texts where text.confidence > 0.6 {
                    let b = text.boundingBox
                    let label = b.width > b.height ? "screen" : "book"
                    objects.append([
                        "label": label as NSString,
                        "confidence": NSNumber(value: text.confidence),
                        "x": NSNumber(value: Float(b.origin.x)),
                        "y": NSNumber(value: Float(1.0 - b.origin.y - b.height)),
                        "w": NSNumber(value: Float(b.width)),
                        "h": NSNumber(value: Float(b.height)),
                    ])
                }
            }

            let payload: NSDictionary = ["objects": objects as NSArray]
            DispatchQueue.main.async { [weak self] in self?.objectSink?(payload) }

        } catch {
            sendEmpty(sink: objectSink, key: "objects")
        }
    }

    private func sendEmpty(sink: FlutterEventSink?, key: String) {
        let p: NSDictionary = [key: NSArray()]
        let s = sink
        DispatchQueue.main.async { s?(p) }
    }
}

// MARK: - Camera delegate

extension AppDelegate: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let buf = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        textureBridge?.latestBuffer = buf
        if textureId >= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.textureRegistry?.textureFrameAvailable(self?.textureId ?? -1)
            }
        }

        frameCount += 1
        if frameCount % 3 == 0 && handReady {
            if #available(iOS 14.0, *) { processHands(buf) }
        }
        if frameCount % 5 == 0 && objectReady {
            processObjects(buf)
        }
    }
}

// MARK: - Helpers

class SinkHandler: NSObject, FlutterStreamHandler {
    let cb: (FlutterEventSink?) -> Void
    init(_ cb: @escaping (FlutterEventSink?) -> Void) { self.cb = cb }
    func onListen(withArguments a: Any?, eventSink e: @escaping FlutterEventSink) -> FlutterError? { cb(e); return nil }
    func onCancel(withArguments a: Any?) -> FlutterError? { cb(nil); return nil }
}

class CameraTextureBridge: NSObject, FlutterTexture {
    var latestBuffer: CVPixelBuffer?
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let b = latestBuffer else { return nil }
        return Unmanaged.passRetained(b)
    }
}
