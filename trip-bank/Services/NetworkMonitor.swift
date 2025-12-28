import SwiftUI
import Network

/// Observable network monitor for connectivity status
/// Usage: @StateObject var networkMonitor = NetworkMonitor.shared
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
            }
        }

        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - SwiftUI Offline Banner

struct OfflineBanner: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.subheadline)
                Text("No Internet Connection")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.9))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - View Modifier

struct NetworkAwareModifier: ViewModifier {
    @StateObject private var networkMonitor = NetworkMonitor.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            VStack {
                OfflineBanner()
                Spacer()
            }
            .animation(.spring(response: 0.3), value: networkMonitor.isConnected)
        }
    }
}

extension View {
    /// Add offline banner overlay
    func networkAware() -> some View {
        modifier(NetworkAwareModifier())
    }
}
