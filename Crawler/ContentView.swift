//
//  ContentView.swift
//  Crawler
//
//  Created by Bijan Vancouver on 2022-08-10.
//

import SwiftUI

struct ContentView: View {
    @State var items: [URL: Page] = [:]

    var body: some View {
        List {
            ForEach(Array(items.keys), id: \.self) { url in
                HStack {
                    Text(url.absoluteString)
                    Text(items[url]?.title ?? "")
                }
            }
        }
        .overlay {
            Text("Count: \(items.count)")
                .padding()
                .background(Color.blue.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            do {
                let start = Date()
                let results = try await crawl(url: URL(string: "https://www.swift.org/blog/")!)
                for try await page in results {
                    self.items[page.url] = page
                }
                let end = Date()
                print("Elapsed: \(end.timeIntervalSince(start))")
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
