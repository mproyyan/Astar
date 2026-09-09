import Foundation
import WatchConnectivity
import Combine

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var state: WatchDirectionState = WatchDirectionState()

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed on Watch: \(error.localizedDescription)")
        } else {
            print("WCSession activated on Watch with state: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let data = applicationContext["stateData"] as? Data,
           let decodedState = try? JSONDecoder().decode(WatchDirectionState.self, from: data) {
            DispatchQueue.main.async {
                self.state = decodedState
            }
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
