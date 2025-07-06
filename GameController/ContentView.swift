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
                                    networkManager: networkManager
                                )
                                ControllerButton(
                                    label: "L2",
                                    networkManager: networkManager
                                )
                            }
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "L3",
                                    networkManager: networkManager
                                )
                                ControllerButton(
                                    label: "L4",
                                    networkManager: networkManager
                                )
                            }
                        }
                        
                        Spacer()
                        
                        // Right buttons
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "R1",
                                    networkManager: networkManager
                                )
                                ControllerButton(
                                    label: "R2",
                                    networkManager: networkManager
                                )
                            }
                            HStack(spacing: 20) {
                                ControllerButton(
                                    label: "R3",
                                    networkManager: networkManager
                                )
                                ControllerButton(
                                    label: "R4",
                                    networkManager: networkManager
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
    let networkManager: NetworkManager
    @State private var isPressed = false
    @State private var longPressTimer: Timer?
    @State private var repeatTimer: Timer?
    
    var body: some View {
        Button(action: {
            // Single tap action - handled by tap gesture
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
        .onTapGesture {
            // Handle single tap
            handleSingleTap()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
                handlePressStart()
            } else {
                handlePressEnd()
            }
        }, perform: {
            // This will be called after the minimum duration, but we handle everything in the pressing callback
        })
    }
    
    private func handleSingleTap() {
        guard !isPressed else { return } // Prevent tap during long press
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = true
        }
        
        networkManager.sendButtonPress(label)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
    
    private func handlePressStart() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = true
        }
        
        // Send initial button press
        networkManager.sendButtonPress(label)
        
        // Start long press timer (wait 0.5 seconds before starting repetition)
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            startRepeating()
        }
    }
    
    private func handlePressEnd() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = false
        }
        
        // Cancel timers
        longPressTimer?.invalidate()
        longPressTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
    
    private func startRepeating() {
        // Start repeating at 20 times per second (50ms interval) for maximum responsiveness
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            networkManager.sendButtonPress(label)
        }
    }
}

class NetworkManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var macIPAddress = "192.168.1.100"
    private var connection: NWConnection?
    private let port: NWEndpoint.Port = 12345
    private var sendQueue = DispatchQueue(label: "sendQueue", qos: .userInitiated)
    private var heartbeatTimer: Timer?
    
    func connectToMac() {
        // Disconnect any existing connection first
        disconnect()
        
        print("🔄 Attempting to connect to Mac at \(macIPAddress):12345 via UDP")
        connectionStatus = "Connecting..."
        
        let host = NWEndpoint.Host(macIPAddress)
        connection = NWConnection(host: host, port: port, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectionStatus = "Connected"
                    print("✅ Successfully connected to Mac via UDP!")
                    self?.startHeartbeat()
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
                    self?.stopHeartbeat()
                case .cancelled:
                    self?.connectionStatus = "Disconnected"
                    self?.isConnected = false
                    self?.connection = nil
                    self?.stopHeartbeat()
                    print("🛑 Connection cancelled")
                default:
                    print("🔄 Connection state: \(state)")
                }
            }
        }
        
        connection?.start(queue: .global())
        
        // Add a timeout for initial connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.connectionStatus == "Connecting..." || self?.connectionStatus.contains("Preparing") == true {
                self?.connectionStatus = "Connection timeout - Check IP address"
                print("⏰ Connection timeout")
            }
        }
    }
    
    func disconnect() {
        stopHeartbeat()
        connection?.cancel()
        connection = nil
        isConnected = false
        connectionStatus = "Disconnected"
    }
    
    private func startHeartbeat() {
        // Send periodic heartbeat to maintain connection status
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        guard let connection = connection, isConnected else { return }
        
        let heartbeatData = "HEARTBEAT".data(using: .utf8)!
        connection.send(content: heartbeatData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ Heartbeat failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = "Connection Lost"
                    self?.isConnected = false
                }
            }
        })
    }
    
    func sendButtonPress(_ button: String) {
        guard let connection = connection, isConnected else {
            print("⚠️ Cannot send button press - not connected")
            return
        }
        
        sendQueue.async {
            let message = button
            let data = message.data(using: .utf8)!
            
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Send error: \(error)")
                    DispatchQueue.main.async {
                        // Don't immediately disconnect on send errors with UDP
                        // as packets can be lost occasionally
                    }
                } else {
                    print("📤 Sent button press: \(button)")
                }
            })
        }
    }
}

#Preview {
    ContentView()
}
