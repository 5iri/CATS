import SwiftUI

struct ChatView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    let activeTasks: [ScheduledTask]
    let energyPercentage: Int
    let onTaskCreate: (TaskCreationResult) -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── HEADER ──
            HStack(spacing: 8) {
                Text("(=^･ω･^=)")
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 1) {
                    Text("CATS Assistant")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(statusSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(statusColor)
                }
                Spacer()
                if chatManager.isLoading {
                    LoadingDots()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(white: 0.1))

            Divider().background(Color(white: 0.18))

            // ── MESSAGES ──
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(chatManager.messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(14)
                }
                .onTapGesture {} // absorb — don't dismiss keyboard inside chat
                .onChange(of: chatManager.messages.count) { _ in
                    if let last = chatManager.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(Color(white: 0.18))

            // ── INPUT BAR ──
            HStack(spacing: 10) {
                TextField(inputPlaceholder, text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: inputText.isEmpty ? "pawprint.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(inputText.isEmpty ? Color(white: 0.4) : .blue)
                }
                .disabled(inputText.isEmpty || chatManager.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(white: 0.1))
            .onTapGesture {} // absorb tap inside input bar
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusSubtitle: String {
        switch chatManager.apiKeyStatus {
        case .valid:    return "Connected · AI ready"
        case .invalid:  return "Invalid key — check Settings"
        case .checking: return "Connecting..."
        case .empty:    return "Add API key in Settings"
        }
    }

    private var statusColor: Color {
        switch chatManager.apiKeyStatus {
        case .valid:              return .green
        case .invalid:            return .red
        case .empty, .checking:   return .gray
        }
    }

    private var inputPlaceholder: String {
        chatManager.apiKeyStatus == .valid
            ? "Add a task or just chat..."
            : "Add API key in Settings first..."
    }

    private func sendMessage() {
        let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        inputText = ""
        chatManager.sendMessage(
            t,
            activeTasks: activeTasks,
            energyPercentage: energyPercentage,
            onTaskCreate: onTaskCreate
        )
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                Text("🐱").font(.system(size: 18))
            }

            if message.isLoading {
                LoadingDots()
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(white: 0.14))
                    .cornerRadius(14)
            } else {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(
                        message.isError ? .red :
                        isUser ? .black : .white
                    )
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(
                        message.isError ? Color.red.opacity(0.15) :
                        isUser ? Color.white : Color(white: 0.16)
                    )
                    .cornerRadius(14)
            }

            if !isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Loading Dots

struct LoadingDots: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever()
                            .delay(Double(i) * 0.13),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Corner radius helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}
