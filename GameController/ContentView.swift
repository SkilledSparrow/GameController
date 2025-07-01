import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var isConnected = false
    @State private var showingIPAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    // Connection status
                    VStack(spacing: 5) {
                        HStack {
                            Circle()
                                .fill(isConnected ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text(networkManager.connectionStatus)
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        
                        // IP address display
                        Text("Mac IP: \(networkManager.macIPAddress)")
                            .foregroundColor(.gray)
                            .font(.caption2)
                            .onTapGesture {
                                showingIPAlert = true
                            }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Controller layout
                    HStack {
                        // Left buttons
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "L1",
                                    action: { networkManager.sendButtonPress("L1") }
                                )
                                ControllerButton(
                                    label: "L2",
                                    action: { networkManager.sendButtonPress("L2") }
                                )
                            }
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "L3",
                                    action: { networkManager.sendButtonPress("L3") }
                                )
                                ControllerButton(
                                    label: "L4",
                                    action: { networkManager.sendButtonPress("L4") }
                                )
                            }
                        }
                        
                        Spacer()
                        
                        // Right buttons
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "R1",
                                    action: { networkManager.sendButtonPress("R1") }
                                )
                                ControllerButton(
                                    label: "R2",
                                    action: { networkManager.sendButtonPress("R2") }
                                )
                            }
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "R3",
                                    action: { networkManager.sendButtonPress("R3") }
                                )
                                ControllerButton(
                                    label: "R4",
                                    action: { networkManager.sendButtonPress("R4") }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Connection controls
                    VStack(spacing: 10) {
                        Button("Change Mac IP") {
                            showingIPAlert = true
                        }
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        if !isConnected {
                            Button("Connect to Mac") {
                                networkManager.connectToMac()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        } else {
                            Button("Disconnect") {
                                networkManager.disconnect()
                            }
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onReceive(networkManager.$isConnected) { connected in
            isConnected = connected
        }
        .alert("Enter Mac IP Address", isPresented: $showingIPAlert) {
            TextField("IP Address", text: $networkManager.macIPAddress)
                .keyboardType(.decimalPad)
            Button("Save") { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your Mac's IP address (found in System Settings → Network)")
        }
    }
}

struct ControllerButton: View {
    let label: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            Text(label)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(isPressed ? Color.blue.opacity(0.8) : Color.gray.opacity(0.6))
                        .shadow(color: .black.opacity(0.3), radius: isPressed ? 2 : 5, x: 0, y: isPressed ? 1 : 3)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

class NetworkManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var macIPAddress = "192.168.1.100" // Make this editable
    private var connection: NWConnection?
    private let port: NWEndpoint.Port = 12345
    
    func connectToMac() {
        // Disconnect any existing connection first
        disconnect()
        
        print("🔄 Attempting to connect to Mac at \(macIPAddress):12345")
        connectionStatus = "Connecting..."
        
        let host = NWEndpoint.Host(macIPAddress)
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                    print("✅ Successfully connected to Mac!")
                case .preparing:
                    self?.connectionStatus = "Preparing..."
                    print("🔄 Preparing connection...")
                case .waiting(let error):
                    self?.connectionStatus = "Waiting: \(error.localizedDescription)"
                    print("⏳ Waiting: \(error.localizedDescription)")
                case .failed(let error):
                    self?.connectionStatus = "Failed: \(error.localizedDescription)"
                    print("❌ Connection failed: \(error.localizedDescription)")
                    self?.isConnected = false
                    self?.connection = nil
                case .cancelled:
                    self?.connectionStatus = "Cancelled"
                    self?.isConnected = false
                    self?.connection = nil
                    print("🛑 Connection cancelled")
                default:
                    print("🔄 Connection state: \(state)")
                }
            }
        }
        
        connection?.start(queue: .global())
        
        // Add a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.connectionStatus == "Connecting..." || self?.connectionStatus.contains("Preparing") == true {
                self?.connectionStatus = "Connection timeout - Check IP address"
                print("⏰ Connection timeout")
            }
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    func sendButtonPress(_ button: String) {
        guard let connection = connection, isConnected else { return }
        
        let message = button
        let data = message.data(using: .utf8)!
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            } else {
                print("Sent button press: \(button)")
            }
        })
    }
}

#Preview {
    ContentView()
}
