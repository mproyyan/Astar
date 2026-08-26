import SwiftUI

// MARK: - Wrapping layout for chips (reused)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Email validation

func isValidEmail(_ text: String) -> Bool {
    let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    return text.range(of: regex, options: .regularExpression) != nil
}

// MARK: - Chip

struct EmailChip: View {
    let email: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(email)
                .font(.subheadline)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(.systemGray5)))
    }
}

// MARK: - Add Trusted Person (manual email entry)

struct AddTrustedPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    @State private var addedEmails: [String] = []
    @State private var draft: String = ""
    @State private var showInvalidHint = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {

                // "With:" field
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("With:")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    FlowLayout(spacing: 6) {
                        ForEach(addedEmails, id: \.self) { email in
                            EmailChip(email: email) {
                                addedEmails.removeAll { $0 == email }
                            }
                        }

                        TextField("Type an iCloud email", text: $draft)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($fieldFocused)
                            .frame(minWidth: 120)
                            .onSubmit { commitDraft() }
                            .onChange(of: draft) { _, newValue in
                                // Auto-convert as soon as it's valid AND ends with space/comma
                                if let last = newValue.last, last == " " || last == "," {
                                    commitDraft()
                                } else {
                                    showInvalidHint = false
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(.rect(cornerRadius: 16))
                .padding(.horizontal, 16)
                .onTapGesture { fieldFocused = true }

                if showInvalidHint {
                    Text("Enter a valid email address")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
//            .padding(.top, 12)
            .navigationTitle("Add Trusted Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        commitDraft() // catch anything still typed but not yet submitted
                        commitSelection()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(addedEmails.isEmpty && !isValidEmail(draft.trimmingCharacters(in: .whitespaces)))
                }
            }
            .onAppear { fieldFocused = true }
        }
    }

    private func commitDraft() {
        let candidate = draft.trimmingCharacters(in: .whitespacesAndCommas)
        guard !candidate.isEmpty else { return }

        if isValidEmail(candidate) {
            if !addedEmails.contains(candidate) {
                addedEmails.append(candidate)
            }
            draft = ""
            showInvalidHint = false
        } else {
            showInvalidHint = true
        }
    }

    private func commitSelection() {
        // Hook into your model — e.g. append new SampleData entries with status: .invited
        print("Inviting:", addedEmails)
    }
}

extension CharacterSet {
    static var whitespacesAndCommas: CharacterSet {
        CharacterSet.whitespaces.union(CharacterSet(charactersIn: ","))
    }
}

#Preview {
    AddTrustedPersonView()
}
