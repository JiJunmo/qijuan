import SwiftUI

struct ProfileChartsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var isTrendYearMode = true
    
    var body: some View {
        VStack(spacing: 24) {
            statusChart
            categoryChart
            trendCanvasChart
        }
    }
    
    // MARK: - 1. 阅读状态统计
    private var statusChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("阅读状态分布")
                .font(.headline)
            
            let total = max(1, viewModel.totalBooks)
            let readP = CGFloat(viewModel.readCount) / CGFloat(total)
            let readingP = CGFloat(viewModel.readingCount) / CGFloat(total)
            let unreadP = CGFloat(viewModel.unreadCount) / CGFloat(total)
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    if readP > 0 {
                        Rectangle()
                            .fill(Color.Theme.primary)
                            .frame(width: geo.size.width * readP)
                    }
                    if readingP > 0 {
                        Rectangle()
                            .fill(Color(hex: "#D99B26"))
                            .frame(width: geo.size.width * readingP)
                    }
                    if unreadP > 0 {
                        Rectangle()
                            .fill(Color(hex: "#8C9D96"))
                            .frame(width: geo.size.width * unreadP)
                    }
                }
                .cornerRadius(8)
            }
            .frame(height: 16)
            
            HStack {
                StatusLegend(color: Color.Theme.primary, text: "已读 \(viewModel.readCount)")
                Spacer()
                StatusLegend(color: Color(hex: "#D99B26"), text: "在读 \(viewModel.readingCount)")
                Spacer()
                StatusLegend(color: Color(hex: "#8C9D96"), text: "未读 \(viewModel.unreadCount)")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 2. 偏好分类统计
    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("藏书偏好")
                .font(.headline)
            
            if viewModel.topCategories.isEmpty {
                Text("暂无藏书")
                    .font(.subheadline)
                    .foregroundColor(Color.Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                let maxCount = viewModel.topCategories.max(by: { $0.count < $1.count })?.count ?? 1
                
                ForEach(viewModel.topCategories) { cat in
                    HStack {
                        Text(cat.name)
                            .font(.subheadline)
                            .frame(width: 60, alignment: .leading)
                        
                        GeometryReader { geo in
                            Capsule()
                                .fill(cat.color)
                                .frame(width: max(10, geo.size.width * CGFloat(cat.count) / CGFloat(maxCount)), height: 8)
                                .position(x: max(10, geo.size.width * CGFloat(cat.count) / CGFloat(maxCount)) / 2, y: geo.size.height / 2)
                        }
                        .frame(height: 8)
                        
                        Text("\(cat.count)")
                            .font(.caption)
                            .foregroundColor(Color.Theme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 3. 自定义 Canvas 趋势图
    private var trendCanvasChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("入库时间趋势")
                    .font(.headline)
                Spacer()
                Picker("模式", selection: $isTrendYearMode) {
                    Text("近一年").tag(true)
                    Text("全部").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
            }
            
            let data = isTrendYearMode ? viewModel.yearTrendData : viewModel.allTrendData
            let maxVal = data.max(by: { $0.value < $1.value })?.value ?? 0
            // 偶数归一化Y轴最高点
            let yMax = max(2, maxVal % 2 == 0 ? maxVal : maxVal + 1)
            
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let paddingBottom: CGFloat = 20
                let chartHeight = height - paddingBottom
                
                let stepX = width / CGFloat(max(1, data.count - 1))
                let points: [CGPoint] = data.enumerated().map { i, dp in
                    let x = CGFloat(i) * stepX
                    let normalizedY = CGFloat(dp.value) / CGFloat(yMax)
                    let y = chartHeight - (chartHeight * normalizedY)
                    return CGPoint(x: x, y: y)
                }
                
                return ZStack(alignment: .topLeading) {
                    // 1. 绘制极细网格底纹
                    Path { path in
                        for i in 0...4 {
                            let y = chartHeight - (chartHeight * CGFloat(i) / 4.0)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    
                    // 2. 绘制平滑折线与渐变遮罩
                    if !data.isEmpty {
                        // 渐变遮罩
                        Path { path in
                            let line = smoothPath(from: points)
                            path.addPath(line)
                            path.addLine(to: CGPoint(x: points.last?.x ?? width, y: chartHeight))
                            path.addLine(to: CGPoint(x: points.first?.x ?? 0, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.Theme.primary.opacity(0.3), Color.Theme.primary.opacity(0.0)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // 折线
                        Path { path in
                            let line = smoothPath(from: points)
                            path.addPath(line)
                        }
                        .stroke(Color.Theme.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // 数据点圆圈与文字
                        ForEach(0..<points.count, id: \.self) { i in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .overlay(Circle().stroke(Color.Theme.primary, lineWidth: 2))
                                .position(points[i])
                            
                            // X 轴文字
                            Text(data[i].label)
                                .font(.system(size: 8))
                                .foregroundColor(Color.Theme.textSecondary)
                                .position(x: points[i].x, y: height - 5)
                        }
                    } else {
                        // 空状态趋势图
                        Text("暂无趋势数据")
                            .font(.subheadline)
                            .foregroundColor(Color.Theme.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
    
    // 生成贝塞尔平滑曲线
    private func smoothPath(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        
        for i in 1..<points.count {
            let current = points[i]
            let previous = points[i - 1]
            let midPoint = CGPoint(x: (current.x + previous.x) / 2, y: (current.y + previous.y) / 2)
            
            let controlPoint1 = CGPoint(x: (midPoint.x + previous.x) / 2, y: previous.y)
            let controlPoint2 = CGPoint(x: (midPoint.x + current.x) / 2, y: current.y)
            
            path.addCurve(to: current, control1: controlPoint1, control2: controlPoint2)
        }
        return path
    }
}

struct StatusLegend: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

#Preview {
    ZStack {
        Color.Theme.background.ignoresSafeArea()
        ProfileChartsView(viewModel: ProfileViewModel())
            .padding()
    }
}
