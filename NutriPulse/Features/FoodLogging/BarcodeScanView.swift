import SwiftUI
import AVFoundation

struct BarcodeScanView: View {
    @Bindable var vm: FoodSearchViewModel
    let date: Date
    let onLogged: (LogSource) -> Void

    @State private var isScanning = true
    @State private var cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        ZStack {
            switch cameraPermission {
            case .authorized:
                cameraLayer
            case .notDetermined:
                Color.black.ignoresSafeArea()
            default:
                permissionDeniedView
            }
        }
        .onAppear {
            vm.resetScanState()
            if cameraPermission == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    // requestAccess calls back on an arbitrary queue. Assigning @State from
                    // there is undefined behaviour: it trips the main-thread checker and the
                    // view can fail to re-render, stranding the user on the black camera
                    // screen after they tapped Allow.
                    Task { @MainActor in
                        cameraPermission = granted ? .authorized : .denied
                    }
                }
            }
        }
        .sheet(item: $vm.selectedResult) { result in
            FoodDetailSheet(vm: vm, result: result, date: date, source: .scan, onLogged: onLogged)
        }
        .onChange(of: vm.selectedResult) { _, result in
            if result == nil { isScanning = true }
        }
        .alert("Barcode Not Found", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("Try Again") { vm.errorMessage = nil; isScanning = true }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: Camera

    private var cameraLayer: some View {
        ZStack {
            BarcodeScannerRepresentable(isScanning: isScanning) { rawValue, symbology in
                isScanning = false
                // FatSecret wants a GTIN-13. Passing a compressed UPC-E code straight through
                // meant every small-package product came back "Barcode Not Found".
                let barcode = BarcodeNormalizer.gtin13(value: rawValue, symbology: symbology) ?? rawValue
                Task { await vm.lookupBarcode(barcode) }
            }
            .ignoresSafeArea()

            ViewfinderOverlay()

            if vm.isLoadingDetail {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                    Text("Looking up food…")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "camera.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.headline)
            Text("Allow camera access in Settings to scan barcodes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.ground)
    }
}

// MARK: - UIViewRepresentable

private struct BarcodeScannerRepresentable: UIViewRepresentable {
    let isScanning: Bool
    // The symbology matters: EAN-8 and UPC-E are both eight digits, and only the symbology
    // distinguishes them. Guessing from the string alone would expand an EAN-8 as if it
    // were a compressed UPC-A.
    let onScanned: (String, BarcodeSymbology) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        context.coordinator.setup(view: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        if isScanning {
            context.coordinator.resume()
        } else {
            context.coordinator.pause()
        }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScanned: (String, BarcodeSymbology) -> Void
        private var session: AVCaptureSession?
        private var hasReported = false

        init(onScanned: @escaping (String, BarcodeSymbology) -> Void) {
            self.onScanned = onScanned
        }

        func setup(view: CameraPreviewView) {
            let session = AVCaptureSession()
            guard
                let device = AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else { return }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            view.previewLayer = previewLayer
            view.layer.addSublayer(previewLayer)

            self.session = session
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }

        func resume() {
            hasReported = false
            guard let session, !session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        }

        func pause() {
            guard let session, session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard
                !hasReported,
                let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                let value = obj.stringValue
            else { return }
            hasReported = true
            pause()

            let symbology: BarcodeSymbology
            switch obj.type {
            case .upce:  symbology = .upce
            case .ean8:  symbology = .ean8
            case .ean13: symbology = .ean13
            default:     symbology = .other
            }
            onScanned(value, symbology)
        }
    }
}

private final class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Viewfinder overlay

private struct ViewfinderOverlay: View {
    private let cornerLen: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.72, 300.0)
            let h = w * 0.6
            let x = (geo.size.width - w) / 2
            let y = (geo.size.height - h) / 2 - 40  // slightly above center
            let rect = CGRect(x: x, y: y, width: w, height: h)

            ZStack {
                // Even-odd fill creates a transparent hole where the scan rect is
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    p.addRect(rect)
                }
                .fill(style: FillStyle(eoFill: true))
                .foregroundStyle(.black.opacity(0.5))

                // Corner brackets
                Path { p in
                    p.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLen))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.minX + cornerLen, y: rect.minY))

                    p.move(to: CGPoint(x: rect.maxX - cornerLen, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLen))

                    p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLen))
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.maxX - cornerLen, y: rect.maxY))

                    p.move(to: CGPoint(x: rect.minX + cornerLen, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLen))
                }
                .stroke(Theme.Colors.primary, lineWidth: 3)

                Text("Align barcode within the frame")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .position(x: geo.size.width / 2, y: rect.maxY + 24)
            }
        }
    }
}
