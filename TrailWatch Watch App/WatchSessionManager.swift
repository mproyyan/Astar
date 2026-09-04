import SwiftUI
import WatchConnectivity
import Foundation
internal import Combine

// These models match the ones in WatchModels.swift
struct WatchPerson: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let status: String
}

struct WatchDirectionState: Codable, Equatable {
    var destinationName: String
    var eta: String
    var estimatedTime: String
    var totalDistance: String
    var isDone: Bool
    var watchingPeople: [WatchPerson]

    init(destinationName: String = "", eta: String = "--.--", estimatedTime: String = "--", totalDistance: String = "--", isDone: Bool = false, watchingPeople: [WatchPerson] = []) {
        self.destinationName = destinationName
        self.eta = eta
        self.estimatedTime = estimatedTime
        self.totalDistance = totalDistance
        self.isDone = isDone
        self.watchingPeople = watchingPeople
    }
}

enum WatchActionMessage: Codable {
    case areYouSafe(message: String)
    case imSafe
    case needHelp
}

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var state = WatchDirectionState()
    @Published var showAlert = false
    @Published var alertMessage = ""

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activated on Watch: \(activationState.rawValue)")
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let data = applicationContext["stateData"] as? Data,
           let decodedState = try? JSONDecoder().decode(WatchDirectionState.self, from: data) {
            DispatchQueue.main.async {
                self.state = decodedState
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let data = message["messageData"] as? Data,
           let watchAction = try? JSONDecoder().decode(WatchActionMessage.self, from: data) {
            DispatchQueue.main.async {
                if case let .areYouSafe(msg) = watchAction {
                    self.alertMessage = msg
                    self.showAlert = true

                    // Optional: play haptic feedback
                    WKInterfaceDevice.current().play(.notification)
                }
            }
        }
    }

    func sendImSafe() {
        guard WCSession.default.activationState == .activated else { return }
        let message = WatchActionMessage.imSafe
        if let data = try? JSONEncoder().encode(message) {
            WCSession.default.sendMessage(["messageData": data], replyHandler: nil)
        }
    }

    func sendNeedHelp() {
        guard WCSession.default.activationState == .activated else { return }
        let message = WatchActionMessage.needHelp
        if let data = try? JSONEncoder().encode(message) {
            WCSession.default.sendMessage(["messageData": data], replyHandler: nil)
        }
    }
}
