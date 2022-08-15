//
//  Crawler.swift
//  Crawler
//
//  Created by Bijan Vancouver on 2022-08-10.
//

import Foundation

private let concurrencyLevel = ProcessInfo.processInfo.activeProcessorCount

func crawl(url: URL) async throws -> AsyncThrowingStream<Page, Error> {
    return AsyncThrowingStream { cont in
        Task {
            let basePrefix = url.absoluteString
            let queue = Queue()
            await queue.enqueue(links: [url])

            await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<concurrencyLevel {
                    group.addTask {
                        while let queuedURL = await queue.dequeue() {
                            let page = try await page(from: queuedURL)
                            await queue.finished(with: queuedURL)
                            cont.yield(page)
                            var links: [URL] = []
                            for link in page.links {
                                if await !queue.exists(url: link) && link.absoluteString.hasPrefix(basePrefix) {
                                    links.append(link)
                                }
                            }
                            await queue.enqueue(links: links)
                        }
                    }
                }
            }
            await queue.reset()
            cont.finish()
        }
    }
}

private actor Queue {
    private var waiting: Set<URL> = []
    private var inProgress: Set<URL> = []
    private var done: Set<URL> = []
    private var pending: [() -> ()] = []

    func enqueue(links: [URL]) {
        for link in links {
            if !inProgress.contains(link) {
                waiting.insert(link)
            }
        }
    }

    func dequeue() async -> URL? {
        guard !Task.isCancelled else { return nil }
        guard let url = waiting.popFirst() else {
            if !inProgress.isEmpty {
                await withCheckedContinuation { cont in
                    pending.append(cont.resume)
                }
                return await dequeue()
            }
            return nil
        }
        inProgress.insert(url)
        return url
    }

    func finished(with url: URL) {
        inProgress.remove(url)
        done.insert(url)

        pending.forEach { $0() }
        pending.removeAll()
    }

    func exists(url: URL) -> Bool {
        done.contains(url)
    }

    func reset() {
        waiting = []
        inProgress = []
        done = []
    }

    var isEmpty: Bool {
        waiting.isEmpty && inProgress.isEmpty
    }
}

struct Page {
    let url: URL
    let title: String
    let links: [URL]
}

private func page(from url: URL) async throws -> Page {
    let (data, _) = try await URLSession.shared.data(from: url)
    let doc = try XMLDocument(data: data, options: .documentTidyHTML)
    let title = try doc.nodes(forXPath: "//title").first?.stringValue ?? ""
    let links: [URL] = try doc.nodes(forXPath: "//a[@href]").compactMap { node in
        guard let node = node as? XMLElement, let href = node.attribute(forName: "href")?.stringValue else {
            return nil
        }
        guard let hrefURL = URL(string: href, relativeTo: url) else { return nil }
        return sanitized(hrefURL)
    }

    return Page(url: url, title: title, links: links)
}

private func sanitized(_ url: URL) -> URL {
    var result = url.absoluteString
    if result.last == "/" {
        result.removeLast()
    }
    if let idx = result.lastIndex(of: "#") {
        result = String(result[..<idx])
    }

    return URL(string: result)!
}
