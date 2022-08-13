//
//  ContentView.swift
//  Crawler
//
//  Created by Bijan Vancouver on 2022-08-10.
//

import SwiftUI

struct ContentView: View {
    @StateObject var crawler = Crawler()

    var body: some View {
        List {
            ForEach(Array(crawler.state.keys), id: \.self) { url in
                HStack {
                    Text(url.absoluteString)
                    Text(crawler.state[url]?.title ?? "")
                }
            }
        }
        .overlay {
            Text("Count: \(crawler.state.count)")
                .padding()
                .background(Color.blue.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            do {
                try await crawler.crawl(url: URL(string: "https://www.swift.org/blog/")!)
            } catch {
                print(error)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
