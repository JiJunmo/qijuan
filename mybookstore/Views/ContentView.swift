//
//  ContentView.swift
//  mybookstore
//
//  Created by 鸡小葵 on 9/6/26.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        TabView {
            BookshelfView()
                .tabItem {
                    Image(systemName: "books.vertical")
                    Text("书架")
                }
            
            ScanTabView()
                .tabItem {
                    Image(systemName: "plus.viewfinder")
                    Text("录入")
                }
            
            CalendarTabView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
            
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person")
                    Text("我的")
                }
        }
        .tint(Color.Theme.primary)
    }
}

#Preview {
    ContentView()
}
