import SwiftUI
import SwiftData
import WebKit

struct CanvasNode: Identifiable {
    let id: UUID
    var request: APIRequest
    var position: CGPoint
}

struct CanvasConnection: Identifiable {
    let id = UUID()
    let from: UUID
    let to: UUID
}

enum NodeExecutionStatus {
    case idle
    case running
    case success(statusCode: Int)
    case failure(error: String)
}

struct CanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRequests: [APIRequest]
    @Query private var environments: [APIEnvironment]
    
    @State private var nodes: [CanvasNode] = []
    @State private var connections: [CanvasConnection] = []
    
    // Pan and Zoom
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var startPanOffset: CGSize = .zero
    
    // Drag node offsets
    @State private var draggedNodeID: UUID?
    @State private var dragOffset: CGSize = .zero
    
    // Connection drawing
    @State private var drawingConnectionFrom: UUID?
    @State private var drawingToPoint: CGPoint?
    
    // Running state
    @State private var nodeExecutionStatuses: [UUID: NodeExecutionStatus] = [:]
    @State private var isExecutingFlow = false
    
    // Search in sidebar
    @State private var searchText = ""
    
    @State private var canvasSize: CGSize = .zero
    
    private var activeEnvironment: APIEnvironment? {
        environments.first(where: { $0.isActive })
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar: Available Requests
            sidebarView
                .frame(width: 260)
                .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Main Canvas Area
            canvasAreaView
        }
        .navigationTitle("Visual Flow Builder")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        isExecutingFlow = true
                        await runFlow()
                        isExecutingFlow = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExecutingFlow ? "arrow.triangle.2.circlepath" : "play.fill")
                        Text(isExecutingFlow ? "Running..." : "Run Flow")
                    }
                    .foregroundStyle(isExecutingFlow ? Color.secondary : Color.green)
                }
                .disabled(nodes.isEmpty || isExecutingFlow)
                
                Button {
                    nodes.removeAll()
                    connections.removeAll()
                    nodeExecutionStatuses.removeAll()
                } label: {
                    Label("Clear Canvas", systemImage: "trash")
                }
                .disabled(nodes.isEmpty || isExecutingFlow)
            }
            
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    zoomScale = max(zoomScale - 0.1, 0.4)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Text("\(Int(zoomScale * 100))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                
                Button {
                    zoomScale = min(zoomScale + 0.1, 2.0)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                
                Button("Reset View") {
                    withAnimation(.spring()) {
                        zoomScale = 1.0
                        panOffset = .zero
                        startPanOffset = .zero
                    }
                }
            }
        }
    }
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search requests...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(12)
            
            // List of requests
            let filteredRequests = allRequests.filter { req in
                searchText.isEmpty || req.name.localizedCaseInsensitiveContains(searchText)
            }
            
            if filteredRequests.isEmpty {
                ContentUnavailableView(
                    "No Requests",
                    systemImage: "tray",
                    description: Text("Create requests or adjust your search to add nodes.")
                )
                .scaleEffect(0.8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Click to Add to Canvas")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                        
                        ForEach(filteredRequests) { req in
                            Button {
                                addNode(for: req)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(req.httpMethod.rawValue)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(methodColor(req.httpMethod))
                                        .cornerRadius(4)
                                    
                                    Text(req.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var canvasAreaView: some View {
        GeometryReader { geo in
            ZStack {
                // Dot Grid Background
                GridBackground(zoom: zoomScale, offset: panOffset)
                    .edgesIgnoringSafeArea(.all)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                panOffset = CGSize(
                                    width: startPanOffset.width + value.translation.width,
                                    height: startPanOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                startPanOffset = panOffset
                            }
                    )
                
                // Canvas Content Wrapper (Supports Zoom and Pan)
                Group {
                    // Connections
                    ForEach(connections) { conn in
                        if let fromNode = nodes.first(where: { $0.id == conn.from }),
                           let toNode = nodes.first(where: { $0.id == conn.to }) {
                            bezierConnectionPath(from: fromNode.position, to: toNode.position)
                                .stroke(
                                    LinearGradient(
                                        colors: [methodColor(fromNode.request.httpMethod), methodColor(toNode.request.httpMethod)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .shadow(color: .blue.opacity(0.2), radius: 2)
                        }
                    }
                    
                    // Temp connecting line
                    if let fromID = drawingConnectionFrom, let toPoint = drawingToPoint,
                       let fromNode = nodes.first(where: { $0.id == fromID }) {
                        bezierConnectionPath(from: fromNode.position, to: toPoint)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4]))
                    }
                    
                    // Nodes
                    ForEach(nodes) { node in
                        let status = nodeExecutionStatuses[node.id] ?? .idle
                        NodeView(node: node, status: status, onConnect: {
                            drawingConnectionFrom = node.id
                            drawingToPoint = CGPoint(x: node.position.x + 80, y: node.position.y)
                        }, onDelete: {
                            nodes.removeAll { $0.id == node.id }
                            connections.removeAll { $0.from == node.id || $0.to == node.id }
                            nodeExecutionStatuses.removeValue(forKey: node.id)
                        })
                        .position(
                            x: node.position.x + (draggedNodeID == node.id ? dragOffset.width / zoomScale : 0),
                            y: node.position.y + (draggedNodeID == node.id ? dragOffset.height / zoomScale : 0)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedNodeID = node.id
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                                        nodes[idx].position.x += value.translation.width / zoomScale
                                        nodes[idx].position.y += value.translation.height / zoomScale
                                    }
                                    draggedNodeID = nil
                                    dragOffset = .zero
                                }
                        )
                        .onTapGesture {
                            if let fromID = drawingConnectionFrom, fromID != node.id {
                                // Add connection
                                connections.append(CanvasConnection(from: fromID, to: node.id))
                                drawingConnectionFrom = nil
                                drawingToPoint = nil
                            }
                        }
                    }
                }
                .scaleEffect(zoomScale)
                .offset(panOffset)
                
                // Connection Overlay Cancel Helper
                if drawingConnectionFrom != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Text("Drag from blue dot to target node, or tap target node. Tap canvas to cancel.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.bottom, 16)
                        }
                    }
                }
                
                // Empty state overlay
                if nodes.isEmpty {
                    ContentUnavailableView(
                        "Empty Canvas",
                        systemImage: "circle.grid.2x2.fill",
                        description: Text("Select requests from the sidebar on the left to add them to your flow.")
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Cancel active drawing
                drawingConnectionFrom = nil
                drawingToPoint = nil
            }
            .onAppear {
                canvasSize = geo.size
            }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = newSize
            }
        }
        // Continuous hover tracker for drawing connections
        .onContinuousHover { phase in
            if drawingConnectionFrom != nil {
                switch phase {
                case .active(let location):
                    // Convert screen hover coordinate back to zoom/pan canvas space
                    let canvasPoint = CGPoint(
                        x: (location.x - panOffset.width) / zoomScale,
                        y: (location.y - panOffset.height) / zoomScale
                    )
                    drawingToPoint = canvasPoint
                case .ended:
                    break
                }
            }
        }
    }
    
    private func addNode(for request: APIRequest) {
        // Place the node relative to current viewport center
        let width = canvasSize.width > 0 ? canvasSize.width : 600
        let height = canvasSize.height > 0 ? canvasSize.height : 600
        let centerX = -panOffset.width / zoomScale + width / 2 / zoomScale
        let centerY = -panOffset.height / zoomScale + height / 2 / zoomScale
        
        // Add a slight cascade offset based on number of nodes
        let offset = CGFloat(nodes.count * 20).truncatingRemainder(dividingBy: 120)
        
        let newNode = CanvasNode(
            id: UUID(),
            request: request,
            position: CGPoint(x: centerX + offset, y: centerY + offset)
        )
        nodes.append(newNode)
    }
    
    private func bezierConnectionPath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        let startPoint = CGPoint(x: from.x + 80, y: from.y)
        let endPoint = CGPoint(x: to.x - 80, y: to.y)
        
        let dx = abs(endPoint.x - startPoint.x)
        let controlWidth = max(dx / 2, 50)
        let control1 = CGPoint(x: startPoint.x + controlWidth, y: startPoint.y)
        let control2 = CGPoint(x: endPoint.x - controlWidth, y: endPoint.y)
        
        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
        return path
    }
    
    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: return .green
        case .POST: return .orange
        case .PUT, .PATCH: return .blue
        case .DELETE: return .red
        default: return .secondary
        }
    }
    
    private func runFlow() async {
        // Clear previous execution statuses
        await MainActor.run {
            nodeExecutionStatuses.removeAll()
        }
        
        // Find starting nodes: nodes that are not the target of any connection
        let startNodes = nodes.filter { node in
            !connections.contains(where: { $0.to == node.id })
        }
        
        // Traverse using indegrees for dependency resolution
        var inDegree: [UUID: Int] = [:]
        for node in nodes {
            inDegree[node.id] = connections.filter { $0.to == node.id }.count
        }
        
        var queue = startNodes
        var isCancelled = false
        
        while !queue.isEmpty {
            let currentNode = queue.removeFirst()
            
            await MainActor.run {
                nodeExecutionStatuses[currentNode.id] = .running
            }
            
            // Artificial delay to make transitions visible
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if isCancelled {
                await MainActor.run {
                    nodeExecutionStatuses[currentNode.id] = .failure(error: "Upstream request failed")
                }
            } else {
                let manager = NetworkManager()
                let response = await manager.execute(currentNode.request, env: activeEnvironment)
                
                if let response = response, response.isSuccess {
                    await MainActor.run {
                        nodeExecutionStatuses[currentNode.id] = .success(statusCode: response.statusCode)
                    }
                } else {
                    isCancelled = true
                    await MainActor.run {
                        let errMsg = response != nil ? "Error \(response!.statusCode)" : "Network Error"
                        nodeExecutionStatuses[currentNode.id] = .failure(error: errMsg)
                    }
                }
            }
            
            // Decrement neighbors and enqueue if eligible
            let children = connections.filter { $0.from == currentNode.id }.map { $0.to }
            for childID in children {
                if let degree = inDegree[childID] {
                    inDegree[childID] = degree - 1
                    if inDegree[childID] == 0 {
                        if let childNode = nodes.first(where: { $0.id == childID }) {
                            queue.append(childNode)
                        }
                    }
                }
            }
        }
    }
}

struct GridBackground: View {
    let zoom: CGFloat
    let offset: CGSize
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let gridSize: CGFloat = 30 * zoom
                let startX = offset.width.truncatingRemainder(dividingBy: gridSize)
                let startY = offset.height.truncatingRemainder(dividingBy: gridSize)
                
                var x = startX
                while x < geo.size.width {
                    var y = startY
                    while y < geo.size.height {
                        path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                        y += gridSize
                    }
                    x += gridSize
                }
            }
            .fill(Color.secondary.opacity(0.15))
        }
    }
}

struct NodeView: View {
    let node: CanvasNode
    let status: NodeExecutionStatus
    var onConnect: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Connection Dot (Input)
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .offset(x: -4)
                .shadow(color: statusColor.opacity(0.5), radius: 2)
            
            // Content Card
            VStack(spacing: 8) {
                HStack(alignment: .center) {
                    Text(node.request.httpMethod.rawValue)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(methodColor(node.request.httpMethod))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    statusIndicator
                }
                
                Text(node.request.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.primary)
                
                if case .failure(let errMsg) = status {
                    Text(errMsg)
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .frame(width: 160, height: 80)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
            .contextMenu {
                Button("Connect Next Node") {
                    onConnect()
                }
                Button("Delete Node", role: .destructive) {
                    onDelete()
                }
            }
            
            // Right Connection Dot (Output & Drag Handle)
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .offset(x: 4)
                .shadow(color: .blue.opacity(0.5), radius: 2)
                .onTapGesture {
                    onConnect()
                }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.6)
        case .success(let code):
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 10))
                Text("\(code)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
            }
        case .failure:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 10))
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle: return .secondary.opacity(0.4)
        case .running: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }
    
    private var borderColor: Color {
        switch status {
        case .idle: return Color.secondary.opacity(0.15)
        case .running: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }
    
    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: return .green
        case .POST: return .orange
        case .PUT, .PATCH: return .blue
        case .DELETE: return .red
        default: return .secondary
        }
    }
}
