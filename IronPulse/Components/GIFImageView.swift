import SwiftUI
import UIKit
import ImageIO

public struct GIFImageView: View {
    private let localName: String?
    private let remoteURL: URL?
    private let contentMode: ContentMode

    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(URL)
        case failed
    }

    public init(localName: String? = nil, remoteURL: URL? = nil, contentMode: ContentMode = .fit) {
        self.localName = localName
        self.remoteURL = remoteURL
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            switch state {
            case .loading:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay(ProgressView())
            case .loaded(let fileURL):
                _GIFPlayerRepresentable(url: fileURL, contentMode: contentMode)
            case .failed:
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: taskID) {
            await resolveSource()
        }
    }

    private var taskID: String {
        "\(localName ?? "")|\(remoteURL?.absoluteString ?? "")"
    }

    private func resolveSource() async {
        if let bundleURL = Self.bundleURL(for: localName) {
            state = .loaded(bundleURL)
            return
        }
        guard let remoteURL else {
            state = .failed
            return
        }
        do {
            state = .loaded(try await Self.cachedFileURL(for: remoteURL))
        } catch {
            state = .failed
        }
    }

    private static func bundleURL(for name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        if let url = Bundle.main.url(forResource: name, withExtension: nil) {
            return url
        }
        let stripped = (name as NSString).deletingPathExtension
        return Bundle.main.url(forResource: stripped, withExtension: "gif")
    }

    private static func cachedFileURL(for remoteURL: URL) async throws -> URL {
        let fileURL = try cacheDirectory().appendingPathComponent(cacheFileName(for: remoteURL))
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func cacheDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("ExerciseGIFs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func cacheFileName(for url: URL) -> String {
        let sanitized = String(url.absoluteString.map { $0.isLetter || $0.isNumber ? $0 : "_" }.suffix(200))
        return sanitized.hasSuffix(".gif") ? sanitized : sanitized + ".gif"
    }
}

internal struct _GIFPlayerRepresentable: UIViewRepresentable {
    let url: URL
    let contentMode: ContentMode

    func makeUIView(context: Context) -> GIFPlayerUIView {
        let view = GIFPlayerUIView()
        view.apply(contentMode: contentMode)
        view.load(url: url)
        return view
    }

    func updateUIView(_ uiView: GIFPlayerUIView, context: Context) {
        uiView.apply(contentMode: contentMode)
        if uiView.loadedURL != url {
            uiView.load(url: url)
        }
    }

    static func dismantleUIView(_ uiView: GIFPlayerUIView, coordinator: ()) {
        uiView.stop()
    }
}

internal final class GIFPlayerUIView: UIView {
    private let imageView = UIImageView()
    private var displayLink: CADisplayLink?
    private var source: CGImageSource?
    private var frameDurations: [TimeInterval] = []
    private var currentIndex = 0
    private var elapsedInFrame: TimeInterval = 0

    private(set) var loadedURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        imageView.clipsToBounds = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    // dentro de un UIView, `ContentMode` sin calificar resuelve a UIView.ContentMode
    func apply(contentMode: SwiftUI.ContentMode) {
        imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
    }

    func load(url: URL) {
        stop()
        loadedURL = url
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        self.source = source

        let frameCount = CGImageSourceGetCount(source)
        frameDurations = (0..<frameCount).map { Self.duration(source: source, index: $0) }
        currentIndex = 0
        elapsedInFrame = 0

        if let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            imageView.image = UIImage(cgImage: firstFrame)
        }

        guard frameCount > 1 else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // Decoding one frame per tick (instead of pre-decoding into
    // UIImageView.animationImages) keeps at most one CGImage resident
    // per player, which is what makes ~150 concurrent GIFs affordable.
    @objc private func tick(_ link: CADisplayLink) {
        guard let source, currentIndex < frameDurations.count else { return }
        elapsedInFrame += link.duration
        guard elapsedInFrame >= frameDurations[currentIndex] else { return }
        elapsedInFrame -= frameDurations[currentIndex]
        currentIndex = (currentIndex + 1) % frameDurations.count
        if let frame = CGImageSourceCreateImageAtIndex(source, currentIndex, nil) {
            imageView.image = UIImage(cgImage: frame)
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        source = nil
        frameDurations = []
        loadedURL = nil
    }

    private static func duration(source: CGImageSource, index: Int) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclamped ?? clamped ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }

    deinit {
        displayLink?.invalidate()
    }
}
