import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()
    @StateObject private var library = LibraryStore()
    @StateObject private var saver = ImageSaver()

    @Environment(\.horizontalSizeClass) private var hSize

    @State private var showLibrary = false
    @State private var showSettings = false
    @State private var sidebarOn = true

    private var isPad: Bool { hSize == .regular }

    private var hostLabel: String {
        if model.urlString.contains("copy4000.com") { return "鏡像" }
        if model.urlString.contains("copy5000.com") { return "主站" }
        return "站點"
    }

    var body: some View {
        Group {
            if isPad {
                padLayout
            } else {
                phoneLayout
            }
        }
        .onAppear { model.prepare() }
        .onChange(of: model.urlString) { newValue in
            library.record(title: model.pageTitle, url: newValue)
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView(library: library) { link in
                if let url = URL(string: link) { model.load(url, force: true) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model)
        }
        .overlay(alignment: .bottom) { saveBanner }
    }

    // MARK: - iPad 分栏

    private var padLayout: some View {
        HStack(spacing: 0) {
            if sidebarOn {
                SidebarView(library: library, model: model, hostLabel: hostLabel) { link in
                    if let url = URL(string: link) { model.load(url, force: true) }
                }
                .frame(width: 300)
                .background(Color(.secondarySystemBackground))
                .transition(.move(edge: .leading))
                Divider()
            }

            VStack(spacing: 0) {
                padBar
                Divider()
                webArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var padBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { sidebarOn.toggle() }
            } label: {
                Image(systemName: sidebarOn ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 17))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Text(model.pageTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            Button { model.toggleMirror() } label: {
                Text(hostLabel)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)

            padIcon("chevron.left", enabled: model.canGoBack) { model.webView?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
            padIcon("chevron.right", enabled: model.canGoForward) { model.webView?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
            padIcon("arrow.clockwise") { model.reload() }
                .keyboardShortcut("r", modifiers: .command)
            padIcon("square.and.arrow.down") { savePageImages() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            padIcon("bookmark") {
                let added = library.toggleBookmark(title: model.pageTitle, url: model.urlString)
                model.showBanner(added ? "已加入書籤" : "已取消書籤")
            }
            .keyboardShortcut("d", modifiers: .command)

            Menu {
                Button { model.goHome() } label: { Label("回首頁", systemImage: "house") }
                Button { savePageImages() } label: { Label("保存本頁圖片", systemImage: "square.and.arrow.down") }
                Button {
                    model.setDesktop(!model.isDesktop)
                    model.showBanner(model.isDesktop ? "電腦版" : "手機版")
                } label: {
                    Label(model.isDesktop ? "切換手機版" : "切換電腦版", systemImage: "desktopcomputer")
                }
                Button { model.toggleMirror() } label: { Label("切換線路", systemImage: "arrow.triangle.2.circlepath") }
                Divider()
                Button { showSettings = true } label: { Label("設定", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(.bar)
    }

    private func padIcon(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.28)
    }

    // MARK: - iPhone 单栏

    private var phoneLayout: some View {
        VStack(spacing: 0) {
            phoneHeader
            webArea
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { phoneFooter }
    }

    private var phoneHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(model.pageTitle)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Button { model.toggleMirror() } label: {
                Text(hostLabel)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(.systemBackground))
    }

    private var phoneFooter: some View {
        HStack(spacing: 0) {
            barButton("chevron.left", enabled: model.canGoBack) { model.webView?.goBack() }
            barButton("chevron.right", enabled: model.canGoForward) { model.webView?.goForward() }
            barButton("arrow.clockwise") { model.reload() }
            barButton("square.and.arrow.down") { savePageImages() }
            barButton("books.vertical") { showLibrary = true }

            Menu {
                Button { model.goHome() } label: { Label("回首頁", systemImage: "house") }
                Button { savePageImages() } label: { Label("保存本頁圖片", systemImage: "square.and.arrow.down") }
                Button {
                    let adding = library.toggleBookmark(title: model.pageTitle, url: model.urlString)
                    model.showBanner(adding ? "已加入書籤" : "已取消書籤")
                } label: {
                    Label(library.isBookmarked(model.urlString) ? "取消書籤" : "加入書籤",
                          systemImage: library.isBookmarked(model.urlString) ? "bookmark.fill" : "bookmark")
                }
                Button {
                    model.setDesktop(!model.isDesktop)
                    model.showBanner(model.isDesktop ? "電腦版" : "手機版")
                } label: {
                    Label(model.isDesktop ? "切換手機版" : "切換電腦版", systemImage: "desktopcomputer")
                }
                Button { model.toggleMirror() } label: { Label("切換線路", systemImage: "arrow.triangle.2.circlepath") }
                Divider()
                Button { showSettings = true } label: { Label("設定", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 19))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 2)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func barButton(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.28)
    }

    // MARK: - 共用

    private var webArea: some View {
        ZStack(alignment: .top) {
            if model.isReady {
                WebViewContainer(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }

            if model.isLoading && model.progress < 1 {
                ProgressView(value: max(0.03, model.progress))
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }

            if let banner = model.banner {
                Text(banner)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
    }

    private var saveBanner: some View {
        Group {
            if saver.saving {
                Text("保存中 \(saver.saved)/\(saver.total)")
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, isPad ? 24 : 66)
            } else if let message = saver.message {
                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, isPad ? 24 : 66)
            }
        }
    }

    private func savePageImages() {
        let referer = model.urlString
        let ua = model.userAgent()
        model.extractImageURLs { urls in
            saver.save(urls: urls, referer: referer, userAgent: ua)
        }
    }
}

// MARK: - iPad 侧栏

struct SidebarView: View {
    @ObservedObject var library: LibraryStore
    @ObservedObject var model: AppModel
    let hostLabel: String
    let onOpen: (String) -> Void

    @State private var tab = 0

    private var items: [SavedLink] {
        tab == 0 ? library.bookmarks : library.history
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("拷貝閱讀器")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Picker("", selection: $tab) {
                Text("書籤").tag(0)
                Text("最近").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(tab == 0 ? "还没有書籤" : "还没有閱讀記錄")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(tab == 0 ? "看到好頁面按 ⌘D 收藏" : "")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            onOpen(item.url)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(item.url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if tab == 0 {
                                Button(role: .destructive) {
                                    library.removeBookmark(id: item.id)
                                } label: { Label("刪除", systemImage: "trash") }
                            }
                        }
                        .swipeActions {
                            if tab == 0 {
                                Button(role: .destructive) {
                                    library.removeBookmark(id: item.id)
                                } label: { Label("刪除", systemImage: "trash") }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack(spacing: 14) {
                Button { model.toggleMirror() } label: {
                    Label(hostLabel, systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                }
                .buttonStyle(.plain)

                Spacer()

                Button { model.goHome() } label: {
                    Image(systemName: "house")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 手机书架

struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    let onOpen: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    private var items: [SavedLink] {
        tab == 0 ? library.bookmarks : library.history
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("書籤").tag(0)
                    Text("最近閱讀").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if items.isEmpty {
                    Spacer()
                    Text(tab == 0 ? "還沒有書籤" : "還沒有閱讀記錄")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(items) { item in
                            Button {
                                onOpen(item.url)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.subheadline).lineLimit(1)
                                    Text(item.url).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                }
                                .padding(.vertical, 2)
                            }
                            .swipeActions {
                                if tab == 0 {
                                    Button(role: .destructive) {
                                        library.removeBookmark(id: item.id)
                                    } label: { Label("刪除", systemImage: "trash") }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("書架")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 设置

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("電腦版網頁", isOn: Binding(
                        get: { model.isDesktop },
                        set: { model.setDesktop($0) }
                    ))
                } header: { Text("閱讀") } footer: {
                    Text("電腦版適合大螢幕看跨頁，手機上字會變小。")
                }

                Section {
                    Button("切換到線路") { model.toggleMirror() }
                    Button("回首頁") { model.goHome() }
                } header: { Text("站點") } footer: {
                    Text("主站 copy5000，鏡像 copy4000。哪個快用哪個。")
                }

                Section {
                    Toggle("屏蔽廣告與彈窗", isOn: $model.blockAds)
                } header: { Text("淨化") } footer: {
                    Text("改動需要重啟 App 生效。已默認屏蔽 exoclick、trafficjunky 等廣告域。")
                }

                Section {
                    shortcutRow("重新載入", "⌘R")
                    shortcutRow("後退 / 前進", "⌘[ / ⌘]")
                    shortcutRow("加入書籤", "⌘D")
                    shortcutRow("保存本頁圖片", "⌘⇧S")
                    shortcutRow("切換書架", "⌘⌥S")
                } header: { Text("iPad 快捷鍵") } footer: {
                    Text("接上鍵盤時可用。")
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.1.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("內核")
                        Spacer()
                        Text("WKWebView").foregroundColor(.secondary)
                    }
                } header: { Text("關於") } footer: {
                    Text("第三方客戶端。漫畫版權歸原作者與網站所有，本應用不存儲任何內容。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func shortcutRow(_ title: String, _ key: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(key)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
