import SwiftUI
import SwiftData

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

struct CanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRequests: [APIRequest]
    
    @State private var nodes: [CanvasNode] = []
    @State private var connections: [CanvasConnection] = []
    
    @State private var draggedNodeID: UUID?
    @State private var dragOffset: CGSize = .zero
    
    @State private var drawingConnectionFrom: UUID?
    @State private var drawingToPoint: CGPoint?
    
    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .edgesIgnoringSafeArea(.all)
            
            // Connections
            ForEach(connections) { conn in
                if let fromNode = nodes.first(where: { $0.id == conn.from }),
                   let toNode = nodes.first(where: { $0.id == conn.to }) {
                    Path { path in
                        path.move(to: fromNode.position)
                        path.addLine(to: toNode.position)
                    }
                    .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [6]))
                }
            }
            
            // Drawing Connection
            if let fromID = drawingConnectionFrom, let toPoint = drawingToPoint,
               let fromNode = nodes.first(where: { $0.id == fromID }) {
                Path { path in
                    path.move(to: fromNode.position)
                    path.addLine(to: toPoint)
                }
                .stroke(Color.blue, lineWidth: 3)
            }
            
            // Nodes
            ForEach($nodes) { $node in
                NodeView(node: node)
                    .position(
                        x: node.position.x + (draggedNodeID == node.id ? dragOffset.width : 0),
                        y: node.position.y + (draggedNodeID == node.id ? dragOffset.height : 0)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                draggedNodeID = node.id
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                node.position.x += value.translation.width
                                node.position.y += value.translation.height
                                draggedNodeID = nil
                                dragOffset = .zero
                            }
                    )
                    .contextMenu {
                        Button("Connect to...") {
                            drawingConnectionFrom = node.id
                            drawingToPoint = node.position
                        }
                        Button("Delete Node") {
                            nodes.removeAll { $0.id == node.id }
                            connections.removeAll { $0.from == node.id || $0.to == node.id }
                        }
                    }
                    .onTapGesture {
                        if let fromID = drawingConnectionFrom, fromID != node.id {
                            connections.append(CanvasConnection(from: fromID, to: node.id))
                            drawingConnectionFrom = nil
                            drawingToPoint = nil
                        }
                    }
            }
        }
        // Mouse tracker for drawing connections
        .onContinuousHover { phase in
            if drawingConnectionFrom != nil {
                switch phase {
                case .active(let location):
                    drawingToPoint = location
                case .ended:
                    break
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    ForEach(allRequests) { req in
                        Button(req.name) {
                            let randomX = CGFloat.random(in: 100...400)
                            let randomY = CGFloat.random(in: 100...400)
                            nodes.append(CanvasNode(id: UUID(), request: req, position: CGPoint(x: randomX, y: randomY)))
                        }
                    }
                } label: {
                    Label("Add Node", systemImage: "plus.circle")
                }
            }
            
            ToolbarItem(placement: .status) {
                Button {
                    // Logic to execute flow
                } label: {
                    Label("Run Flow", systemImage: "play.fill")
                }
                .disabled(nodes.isEmpty)
            }
        }
        .navigationTitle("Visual Flow Builder")
    }
}

struct NodeView: View {
    let node: CanvasNode
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(node.request.httpMethod.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(methodColor(node.request.httpMethod))
                    .cornerRadius(4)
                
                Spacer()
            }
            
            Text(node.request.name)
                .font(.subheadline.bold())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 140, height: 70)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
