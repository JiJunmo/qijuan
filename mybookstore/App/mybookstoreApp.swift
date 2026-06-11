//
//  mybookstoreApp.swift
//  mybookstore
//
//  Created by 鸡小葵 on 9/6/26.
//

import SwiftUI
import SwiftData

@main
struct mybookstoreApp: App {
    init() {
        // 注册默认的 API 地址
        UserDefaults.standard.register(defaults: [
            "customApiUrl": "http://118.25.58.73:11221/api/book"
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BookItem.self, NoteItem.self, ReadingSession.self])
    }
}
