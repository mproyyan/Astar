import Foundation
import WatchConnectivity
import ComposableArchitecture
import Combine

/// ============================================================================
/// ⌚ WATCH CONNECTIVITY DEPENDENCY CLIENT
/// ============================================================================
///
/// 💡 TEORI & ANALOGI PYTHON / COMPUTER SCIENCE:
/// - Framework `WatchConnectivity` klasik mengandalkan callback delegate UIKit (`WCSessionDelegate`).
/// - File ini menerapkan **Modern Stream Adapter**:
///   Mengubah model callback kuno berbasis delegate menjadi model modern Swift Concurrency
///   yaitu `AsyncStream`.
/// - Mirip dengan membungkus callback WebSocket atau Socket IO menjadi async iterator di Python
///   (`async for msg in stream:`).
/// ============================================================================
@DependencyClient
public struct WatchConnectivityClient: Sendable {
    public var isSupported: @Sendable () -> Bool = { false }
    public var activateSession: @Sendable () async -> Void
    public var updateState: @Sendable (_ state: WatchDirectionState) async throws -> Void
    public var sendMessage: @Sendable (_ message: WatchActionMessage) async throws -> Void

    public var stateStream: @Sendable () async -> AsyncStream<WatchDirectionState> = { .finished }
    public var messageStream: @Sendable () async -> AsyncStream<WatchActionMessage> = { .finished }
}

public enum WatchConnectivityClientError: Error {
    case sessionNotSupported
    case notActivated
}

extension WatchConnectivityClient: DependencyKey {
    public static let liveValue = WatchConnectivityClient.live()

    public static let testValue: Self = Self(
        isSupported: { false },
        activateSession: {},
        updateState: { _ in },
        sendMessage: { _ in },
        stateStream: { .finished },
        messageStream: { .finished }
    )

    public static let previewValue: Self = Self(
        isSupported: { false },
        activateSession: {},
        updateState: { _ in },
        sendMessage: { _ in },
        stateStream: { .finished },
        messageStream: { .finished }
    )

    public static func live() -> Self {
        // Delegate internal untuk menangkap event dari radio Bluetooth WCSession
        final class Delegate: NSObject, WCSessionDelegate, Sendable {
            let stateContinuation: AsyncStream<WatchDirectionState>.Continuation
            let messageContinuation: AsyncStream<WatchActionMessage>.Continuation

            init(stateContinuation: AsyncStream<WatchDirectionState>.Continuation,
                 messageContinuation: AsyncStream<WatchActionMessage>.Continuation) {
                self.stateContinuation = stateContinuation
                self.messageContinuation = messageContinuation
                super.init()
            }

            func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
                if let error = error {
                    print("WCSession activation failed: \(error.localizedDescription)")
                } else {
                    print("WCSession activated with state: \(activationState.rawValue)")
                }
            }

            #if os(iOS)
            func sessionDidBecomeInactive(_ session: WCSession) { }
            func sessionDidDeactivate(_ session: WCSession) {
                // Jika user berganti Apple Watch, sesi diaktifkan ulang
                session.activate()
            }
            #endif

            // Menerima update status teranyar yang disinkronkan di latar belakang
            func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
                if let data = applicationContext["stateData"] as? Data,
                   let state = try? JSONDecoder().decode(WatchDirectionState.self, from: data) {
                    stateContinuation.yield(state)
                }
            }

            // Menerima pesan instan / real-time (misal: tombol SOS ditekan di jam tangan)
            func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
                if let data = message["messageData"] as? Data,
                   let watchAction = try? JSONDecoder().decode(WatchActionMessage.self, from: data) {
                    messageContinuation.yield(watchAction)
                }
            }
        }

        // Inisialisasi saluran AsyncStream dengan pola producer-consumer
        let (stateStream, stateContinuation) = AsyncStream<WatchDirectionState>.makeStream()
        let (messageStream, messageContinuation) = AsyncStream<WatchActionMessage>.makeStream()

        let delegate = Delegate(stateContinuation: stateContinuation, messageContinuation: messageContinuation)

        return WatchConnectivityClient(
            isSupported: { WCSession.isSupported() },
            activateSession: {
                guard WCSession.isSupported() else { return }
                let session = WCSession.default
                session.delegate = delegate
                session.activate()
            },
            updateState: { state in
                guard WCSession.isSupported() else { throw WatchConnectivityClientError.sessionNotSupported }
                let session = WCSession.default
                if session.activationState != .activated {
                    session.activate()
                }

                // Serialisasi data ke format JSON binary
                let data = try JSONEncoder().encode(state)
                do {
                    // Mengirim kamus data ke Apple Watch secara hemat daya
                    try session.updateApplicationContext(["stateData": data])
                } catch {
                    print("WCSession updateApplicationContext error: \(error)")
                    throw error
                }
            },
            sendMessage: { message in
                guard WCSession.isSupported() else { throw WatchConnectivityClientError.sessionNotSupported }
                let session = WCSession.default
                if session.activationState != .activated {
                    session.activate()
                }

                let data = try JSONEncoder().encode(message)
                session.sendMessage(["messageData": data], replyHandler: nil, errorHandler: { error in
                    print("WCSession sending message failed: \(error.localizedDescription)")
                })
            },
            stateStream: { stateStream },
            messageStream: { messageStream }
        )
    }
}

extension DependencyValues {
    public var watchConnectivity: WatchConnectivityClient {
        get { self[WatchConnectivityClient.self] }
        set { self[WatchConnectivityClient.self] = newValue }
    }
}
