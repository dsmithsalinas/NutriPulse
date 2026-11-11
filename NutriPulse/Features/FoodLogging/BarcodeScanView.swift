import SwiftUI
import AVFoundation

struct BarcodeScanView: View {
    @Bindable var vm: FoodSearchViewModel
    let date: Date
    let headerMeal: Meal
    let onLogged: (LogSource) -> Void

    @State private var isScanning = true
    @State private var cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)

    // Read-only screenshot routes never initialize capture hardware or request permission.
    private var layoutPreview: Int {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--log-preview") else { return 0 }
        if ProcessInfo.processInfo.arguments.contains("--scan-denied-preview") { return 2 }
        return ProcessInfo.processInfo.arguments.contains("--scan-preview") ? 1 : 0
        #else
        return 0
        #endif
    }

    var body: some View {
        ZStack {
            if layoutPreview == 1 {
                cameraLayer
            } else if layoutPreview == 2 {
                permissionDeniedView
            } else {
                switch cameraPermission {
                case .authorized:
                    cameraLayer
                case .notDetermined:
                    Color.black.ignoresSafeArea()
                default:
                    permissionDeniedView
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous))
        .onAppear {
            vm.resetScanState()
            vm.selectedMeal = headerMeal
            guard layoutPreview == 0 else { return }
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
            if layoutPreview == 1 {
                Color(hex: 0x334155)
                    .overlay { Image(systemName: "barcode").font(.system(size: 72)).foregroundStyle(.white.opacity(0.55)).accessibilityHidden(true) }
            } else {
                BarcodeScannerRepresentable(isScanning: isScanning) { rawValue, symbology in
                    isScanning = false
                    // FatSecret wants a GTIN-13. Passing a compressed UPC-E code straight through
                    // meant every small-package product came back "Barcode Not Found".
                    let barcode = BarcodeNormalizer.gtin13(value: rawValue, symbology: symbology) ?? rawValue
                    vm.selectedMeal = headerMeal
                    Task { await vm.lookupBarcode(barcode) }
                }
            }

            ViewfinderOverlay()
            if layoutPreview == 1 {
                Text("Simulated camera preview")
                    .font(Theme.Fonts.body(12, .semibold)).foregroundStyle(.white)
                    .padding(10).background(.black.opacity(0.6), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12)
            }

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
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "camera.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Colors.textFaint)
                Text("Camera Access Required")
                    .font(Theme.Fonts.display(20, .bold, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Allow camera access in Settings to scan barcodes.")
                    .font(Theme.Fonts.body(15))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.brandPrimary)
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
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
            view.configureRotation(device: device, layer: previewLayer)

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
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    func configureRotation(device: AVCaptureDevice, layer: AVCaptureVideoPreviewLayer) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotationCoordinator = coordinator
        // AVFoundation delivers these observations on the main queue. The coordinator
        // follows the actual camera and preview layer across rotation/display changes.
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak layer] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            guard let connection = layer?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }

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
            let w = min(geo.size.width * 0.72, 300.0, max(0, geo.size.height - 96) / 0.6)
            let h = w * 0.6
            let x = (geo.size.width - w) / 2
            let y = max(16, (geo.size.height - h) / 2 - 40)
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(radius: 2)
                    .frame(width: max(0, geo.size.width - 32))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16)
            }
        }
    }
}
