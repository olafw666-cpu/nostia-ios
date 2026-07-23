import SwiftUI
import AVFoundation

/// In-app camera capture sheet (ported from nostia-adventures-future §4). The
/// photo library picker is deliberately NOT offered — completion photos must
/// come from a live capture inside the nonce window. The JPEG is delivered in
/// memory and uploaded directly; it is never saved to the user's camera roll,
/// which also means EXIF from the library can never masquerade as a fresh
/// capture. Camera permission (NSCameraUsageDescription) already ships for the
/// vault QR scanner.
struct CameraCaptureView: View {
    let promptText: String
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = CameraController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                    Text("Camera access is needed to add a photo")
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding()
            }

            VStack {
                // Stop reminder banner so the user frames the right thing.
                Text(promptText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                HStack {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.white)
                        .padding()

                    Spacer()

                    Button {
                        camera.capturePhoto()
                    } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                            Circle().fill(.white).frame(width: 60, height: 60)
                        }
                    }
                    .disabled(!camera.authorized || camera.isCapturing)
                    .accessibilityLabel("Take photo")

                    Spacer()

                    // Layout balance for the cancel button.
                    Color.clear.frame(width: 70, height: 44)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            camera.onPhoto = onCapture
            camera.start()
        }
        .onDisappear { camera.stop() }
    }
}

// MARK: - AVFoundation plumbing

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "nostia.capture.session")

    @Published var authorized = false
    @Published var isCapturing = false

    var onPhoto: ((Data) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorized = granted
                    if granted { self?.configureAndRun() }
                }
            }
        default:
            authorized = false
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [self] in
            guard session.inputs.isEmpty else {
                if !session.isRunning { session.startRunning() }
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .photo
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhoto() {
        isCapturing = true
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        DispatchQueue.main.async { [self] in
            isCapturing = false
            guard error == nil, let data = photo.fileDataRepresentation() else { return }
            onPhoto?(data)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
