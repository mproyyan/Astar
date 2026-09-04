import SwiftUI

struct ContentView: View {
    @StateObject private var watchManager = WatchSessionManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if watchManager.state.destinationName.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Active Journey")
                            .font(.headline)
                        Text("Start navigation on your iPhone to see it here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                } else if watchManager.state.isDone {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("You've Reached")
                            .font(.headline)
                        Text(watchManager.state.destinationName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                } else {
                    // Active Navigation Status
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To \(watchManager.state.destinationName)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        HStack {
                            Text(watchManager.state.estimatedTime)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            HStack(spacing: 4) {
                                Text(watchManager.state.eta)
                                Circle().frame(width: 3, height: 3)
                                Text(watchManager.state.totalDistance)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Watching People Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Watching")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(watchManager.state.watchingPeople.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if watchManager.state.watchingPeople.isEmpty {
                            Text("No one is watching right now.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(watchManager.state.watchingPeople) { person in
                                HStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    VStack(alignment: .leading) {
                                        Text(person.name)
                                            .font(.footnote.weight(.medium))
                                        Text(person.status)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
            .alert(isPresented: $watchManager.showAlert) {
                Alert(
                    title: Text("Are you safe?"),
                    message: Text(watchManager.alertMessage),
                    primaryButton: .default(Text("I'm Safe"), action: {
                        watchManager.sendImSafe()
                    }),
                    secondaryButton: .destructive(Text("Need Help"), action: {
                        watchManager.sendNeedHelp()
                    })
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
