import SwiftUI
import SwiftData

struct ProfileTabView: View {
    @Query private var books: [BookItem]
    @Query private var sessions: [ReadingSession]
    @Query private var notes: [NoteItem]
    
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. 全局概览统计板 (Top Stats)
                        topStatsBoard
                        
                        // 2. 可视化图表层
                        ProfileChartsView(viewModel: viewModel)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("我的")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color.Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsOverlay()
            }
            .onAppear {
                viewModel.calculateStats(books: books, sessions: sessions, notes: notes)
            }
            .onChange(of: books) { _, _ in viewModel.calculateStats(books: books, sessions: sessions, notes: notes) }
            .onChange(of: sessions) { _, _ in viewModel.calculateStats(books: books, sessions: sessions, notes: notes) }
            .onChange(of: notes) { _, _ in viewModel.calculateStats(books: books, sessions: sessions, notes: notes) }
        }
    }
    
    // MARK: - 概览卡片
    private var topStatsBoard: some View {
        HStack(spacing: 16) {
            StatBox(title: "总阅读时长", value: "\(viewModel.totalReadingMinutes)", unit: "分钟")
            StatBox(title: "总藏书量", value: "\(viewModel.totalBooks)", unit: "本")
            StatBox(title: "总笔记数", value: "\(viewModel.totalNotes)", unit: "条")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color.Theme.textSecondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.Theme.textPrimary)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(Color.Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileTabView()
}
