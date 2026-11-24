import Foundation
import UIKit

final class ImageSaver: ObservableObject {
    @Published var saving = false
    @Published var saved = 0
    @Published var total = 0
    @Published var message: String?

    private let queue = DispatchQueue(label: "com.local.copyreader.save", qos: .utility)
    private var working = false

    func save(urls: [URL], referer: String, userAgent: String) {
        guard !working else { return }
        guard !urls.isEmpty else {
            message = "本页没有找到可保存的图片"
            clearMessageLater()
            return
        }
        working = true
        DispatchQueue.main.async {
            self.saving = true
            self.saved = 0
            self.total = urls.count
            self.message = nil
        }

        queue.async { [weak self] in
            guard let self else { return }
            for url in urls {
                var request = URLRequest(url: url)
                request.setValue(referer, forHTTPHeaderField: "Referer")
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 25

                let semaphore = DispatchSemaphore(value: 0)
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    if let data, let image = UIImage(data: data) {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        DispatchQueue.main.async { self.saved += 1 }
                    }
                    semaphore.signal()
                }.resume()
                _ = semaphore.wait(timeout: .now() + 40)
            }

            DispatchQueue.main.async {
                self.saving = false
                self.working = false
                self.message = "已保存 \(self.saved)/\(self.total) 张到相册"
                self.clearMessageLater()
            }
        }
    }

    private func clearMessageLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.message = nil
        }
    }
}
