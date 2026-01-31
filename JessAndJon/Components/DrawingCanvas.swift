import SwiftUI

struct DrawingCanvas: View {
    var onSave: (UIImage) -> Void
    
    @State private var lines: [DrawingLine] = []
    @State private var currentLine: DrawingLine?
    @State private var selectedColor: Color = AppTheme.accentPink
    @State private var lineWidth: CGFloat = 4
    @State private var canvasSize: CGSize = .zero
    
    let colors: [Color] = [
        AppTheme.accentPink,
        AppTheme.accentPurple,
        AppTheme.heartRed,
        AppTheme.gradientMid,
        Color.black,
        Color.white
    ]
    
    let widths: [CGFloat] = [2, 4, 8, 12]
    
    var body: some View {
        VStack(spacing: 0) {
            // Canvas
            GeometryReader { geo in
                ZStack {
                    // Background
                    Color.white
                    
                    // Grid pattern for visual appeal
                    gridPattern
                    
                    // Drawing layer
                    Canvas { context, size in
                        for line in lines {
                            drawLine(line, in: context)
                        }
                        if let current = currentLine {
                            drawLine(current, in: context)
                        }
                    }
                    .gesture(drawingGesture)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.mainGradient, lineWidth: 3)
                )
                .shadow(color: AppTheme.accentPink.opacity(0.2), radius: 15, x: 0, y: 8)
                .onAppear {
                    canvasSize = geo.size
                }
            }
            .padding(20)
            
            // Tools
            VStack(spacing: 16) {
                // Color picker
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        colorButton(color: color)
                    }
                }
                
                // Width picker
                HStack(spacing: 16) {
                    ForEach(widths, id: \.self) { width in
                        widthButton(width: width)
                    }
                    
                    Spacer()
                    
                    // Undo button
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(lines.isEmpty ? AppTheme.textSecondary.opacity(0.5) : AppTheme.accentPurple)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(AppTheme.lavender.opacity(0.5))
                            )
                    }
                    .disabled(lines.isEmpty)
                    
                    // Clear button
                    Button(action: clearCanvas) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(lines.isEmpty ? AppTheme.textSecondary.opacity(0.5) : AppTheme.heartRed)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(AppTheme.softPink.opacity(0.3))
                            )
                    }
                    .disabled(lines.isEmpty)
                }
                
                // Save button
                Button(action: saveDrawing) {
                    HStack(spacing: 8) {
                        Text("Save Drawing")
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(lines.isEmpty)
                .opacity(lines.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(AppTheme.backgroundPrimary)
    }
    
    // MARK: - Grid Pattern
    private var gridPattern: some View {
        GeometryReader { geo in
            Path { path in
                let gridSize: CGFloat = 20
                let columns = Int(geo.size.width / gridSize)
                let rows = Int(geo.size.height / gridSize)
                
                // Vertical lines
                for i in 0...columns {
                    let x = CGFloat(i) * gridSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                
                // Horizontal lines
                for i in 0...rows {
                    let y = CGFloat(i) * gridSize
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(AppTheme.lavender.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    // MARK: - Drawing Gesture
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = value.location
                
                if currentLine == nil {
                    currentLine = DrawingLine(
                        color: selectedColor,
                        lineWidth: lineWidth,
                        points: [point]
                    )
                } else {
                    currentLine?.points.append(point)
                }
            }
            .onEnded { _ in
                if let line = currentLine {
                    lines.append(line)
                    currentLine = nil
                }
            }
    }
    
    // MARK: - Draw Line
    private func drawLine(_ line: DrawingLine, in context: GraphicsContext) {
        var path = Path()
        
        guard let firstPoint = line.points.first else { return }
        path.move(to: firstPoint)
        
        for point in line.points.dropFirst() {
            path.addLine(to: point)
        }
        
        context.stroke(
            path,
            with: .color(line.color),
            style: StrokeStyle(
                lineWidth: line.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
    
    // MARK: - Color Button
    private func colorButton(color: Color) -> some View {
        Button(action: { selectedColor = color }) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                
                if color == .white {
                    Circle()
                        .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 36, height: 36)
                }
                
                if selectedColor == color {
                    Circle()
                        .stroke(AppTheme.textPrimary, lineWidth: 3)
                        .frame(width: 44, height: 44)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Width Button
    private func widthButton(width: CGFloat) -> some View {
        Button(action: { lineWidth = width }) {
            ZStack {
                Circle()
                    .fill(lineWidth == width ? AppTheme.softGradient : Color.clear)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(selectedColor)
                    .frame(width: width * 2, height: width * 2)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    private func undo() {
        guard !lines.isEmpty else { return }
        lines.removeLast()
    }
    
    private func clearCanvas() {
        withAnimation {
            lines.removeAll()
        }
    }
    
    private func saveDrawing() {
        // Render canvas to image
        let renderer = ImageRenderer(content: canvasView)
        renderer.scale = 3.0 // High resolution
        
        if let uiImage = renderer.uiImage {
            onSave(uiImage)
        }
    }
    
    // View for rendering
    private var canvasView: some View {
        ZStack {
            Color.white
            
            Canvas { context, size in
                for line in lines {
                    drawLine(line, in: context)
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - Drawing Line Model
struct DrawingLine {
    var color: Color
    var lineWidth: CGFloat
    var points: [CGPoint]
}

#Preview {
    DrawingCanvas(onSave: { _ in })
}
