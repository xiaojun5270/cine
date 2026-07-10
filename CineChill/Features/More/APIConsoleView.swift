import SwiftUI

struct APIEndpointManifest: Decodable, Sendable {
    let count: Int
    let endpoints: [APIEndpoint]
}

struct APIEndpoint: Decodable, Identifiable, Hashable, Sendable {
    var id: String { "\(method) \(path)" }
    let group: String
    let method: String
    let path: String
    let summary: String
    let description: String
    let queryParams: [APIQueryParam]
    let bodyFields: [APIBodyField]
    let hasRequestBody: Bool

    var pathParams: [APIQueryParam] {
        let names = path.split(separator: "/").compactMap { part -> String? in
            guard part.hasPrefix("{"), part.hasSuffix("}") else { return nil }
            return String(part.dropFirst().dropLast())
        }
        return names.map {
            APIQueryParam(name: $0, location: "path", type: "string", required: true, description: "")
        }
    }

    var needsInput: Bool {
        !pathParams.isEmpty || !queryParams.isEmpty || !bodyFields.isEmpty || hasRequestBody
    }
}

struct APIQueryParam: Decodable, Hashable, Sendable {
    let name: String
    let location: String
    let type: String
    let required: Bool
    let description: String
}

struct APIBodyField: Decodable, Hashable, Sendable {
    let name: String
    let type: String
    let required: Bool
    let description: String
}

enum APIEndpointCatalog {
    private static let cachedEndpoints: [APIEndpoint] = decode()

    static func load() -> [APIEndpoint] {
        cachedEndpoints
    }

    static func loadAsync() async -> [APIEndpoint] {
        await Task.detached(priority: .userInitiated) {
            load()
        }.value
    }

    private static func decode() -> [APIEndpoint] {
        guard let url = Bundle.main.url(forResource: "api_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(APIEndpointManifest.self, from: data)
        else { return [] }
        return manifest.endpoints
    }
}

struct APIConsoleView: View {
    @State private var endpoints: [APIEndpoint] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedEndpoint: APIEndpoint?

    private var filteredGroups: [(String, [APIEndpoint])] {
        let filtered = endpoints.filter { endpoint in
            guard !searchText.isEmpty else { return true }
            let haystack = "\(endpoint.group) \(endpoint.method) \(endpoint.path) \(endpoint.summary) \(endpoint.description)"
                .lowercased()
            return haystack.contains(searchText.lowercased())
        }
        return Dictionary(grouping: filtered, by: \.group)
            .map { ($0.key, $0.value.sorted { $0.path < $1.path }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ModuleScaffold(
            title: "接口总控",
            isLoading: isLoading,
            error: nil,
            isEmpty: !isLoading && filteredGroups.isEmpty,
            emptyTitle: "没有匹配接口",
            emptyIcon: "point.3.connected.trianglepath.dotted"
        ) {
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("全量接口")
                        .font(.headline)
                    Text("已载入 \(endpoints.count) 个接口。业务页未覆盖的操作，可在这里搜索、填参并执行。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(filteredGroups, id: \.0) { pair in
                let group = pair.0
                let items = pair.1
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: group, subtitle: "\(items.count) 个接口")
                    ForEach(items) { endpoint in
                        endpointCard(endpoint)
                    }
                }
            }
        }
        .task { await loadEndpoints() }
        .searchable(text: $searchText, prompt: "搜索接口、路径、分组")
        .sheet(item: $selectedEndpoint) { endpoint in
            EndpointRunnerView(endpoint: endpoint)
        }
    }

    @MainActor
    private func loadEndpoints() async {
        guard endpoints.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        endpoints = await APIEndpointCatalog.loadAsync()
        isLoading = false
    }

    private func endpointCard(_ endpoint: APIEndpoint) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(endpoint.method)
                        .font(.caption.bold())
                        .foregroundStyle(methodColor(endpoint.method))
                    Text(endpoint.summary.isEmpty ? endpoint.path : endpoint.summary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                }
                Text(endpoint.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !endpoint.description.isEmpty {
                    Text(endpoint.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    if endpoint.needsInput {
                        GlassPill("需填参", systemImage: "square.and.pencil", tint: Theme.accentWarm)
                    } else {
                        GlassPill("可直接执行", systemImage: "bolt.fill")
                    }
                    Spacer()
                    ModuleActionButton(title: "打开", systemImage: "arrow.up.forward.app", prominent: true) {
                        selectedEndpoint = endpoint
                    }
                }
            }
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": .green
        case "POST": Theme.accent
        case "PATCH", "PUT": Theme.accentWarm
        case "DELETE": .red
        default: .secondary
        }
    }
}

private struct EndpointRunnerView: View {
    let endpoint: APIEndpoint

    @Environment(\.dismiss) private var dismiss
    @State private var pathValues: [String: String]
    @State private var queryValues: [String: String]
    @State private var bodyValues: [String: String]
    @State private var rawBody = ""
    @State private var result: JSONValue?
    @State private var errorText: String?
    @State private var isRunning = false

    init(endpoint: APIEndpoint) {
        self.endpoint = endpoint
        _pathValues = State(initialValue: Dictionary(uniqueKeysWithValues: endpoint.pathParams.map { ($0.name, "") }))
        _queryValues = State(initialValue: Dictionary(uniqueKeysWithValues: endpoint.queryParams.map { ($0.name, "") }))
        _bodyValues = State(initialValue: Dictionary(uniqueKeysWithValues: endpoint.bodyFields.map { ($0.name, "") }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    parameterSection("路径参数", fields: endpoint.pathParams, values: $pathValues)
                    parameterSection("查询参数", fields: endpoint.queryParams, values: $queryValues)
                    bodySection
                    actionSection
                    resultSection
                }
                .padding(Theme.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(endpoint.method)
            .navigationBarTitleDisplayMode(.inline)
            .appLiquidNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(endpoint.summary.isEmpty ? "接口" : endpoint.summary)
                    .font(.headline)
                Text(endpoint.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !endpoint.description.isEmpty {
                    Text(endpoint.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func parameterSection(_ title: String, fields: [APIQueryParam], values: Binding<[String: String]>) -> some View {
        if !fields.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.headline)
                    ForEach(fields, id: \.name) { field in
                        APIFieldEditor(
                            title: field.name,
                            type: field.type,
                            required: field.required,
                            text: binding(for: field.name, in: values)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bodySection: some View {
        if endpoint.hasRequestBody || !endpoint.bodyFields.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("请求体").font(.headline)
                    if endpoint.bodyFields.isEmpty || endpoint.bodyFields.contains(where: { $0.name == "(value)" }) {
                        TextField("JSON 对象，例如 {\"enabled\":true}", text: $rawBody, axis: .vertical)
                            .lineLimit(3...8)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
                    }
                    ForEach(endpoint.bodyFields.filter { $0.name != "(value)" }, id: \.name) { field in
                        APIFieldEditor(
                            title: field.name,
                            type: field.type,
                            required: field.required,
                            text: binding(for: field.name, in: $bodyValues)
                        )
                    }
                }
            }
        }
    }

    private var actionSection: some View {
        GlassPrimaryButton(title: isRunning ? "执行中" : "执行接口", systemImage: "paperplane.fill", isLoading: isRunning) {
            Task { await run() }
        }
        .disabled(isRunning)
    }

    @ViewBuilder
    private var resultSection: some View {
        if let errorText {
            GlassCard {
                Text(errorText)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let result {
            JSONKeyValueCard(title: "返回结果", json: result, limit: 120)
        }
    }

    private func binding(for key: String, in values: Binding<[String: String]>) -> Binding<String> {
        Binding(
            get: { values.wrappedValue[key] ?? "" },
            set: { values.wrappedValue[key] = $0 }
        )
    }

    private func run() async {
        isRunning = true
        errorText = nil
        defer { isRunning = false }

        do {
            let path = resolvedPath()
            let method = APIClient.Method(rawValue: endpoint.method.uppercased()) ?? .get
            let query = queryValues.mapValues { $0.isEmpty ? nil : $0 }
            let body = try requestBody()
            if let body {
                result = try await APIClient.shared.request(method, path, query: query, body: body)
            } else {
                result = try await APIClient.shared.request(method, path, query: query)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func resolvedPath() -> String {
        var path = endpoint.path
        for (key, value) in pathValues where !value.isEmpty {
            path = path.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return path
    }

    private func requestBody() throws -> JSONValue? {
        guard endpoint.hasRequestBody || !endpoint.bodyFields.isEmpty else { return nil }

        if !rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let data = rawBody.data(using: .utf8) {
            return try JSONDecoder().decode(JSONValue.self, from: data)
        }

        var dict: [String: Any?] = [:]
        for field in endpoint.bodyFields where field.name != "(value)" {
            let value = bodyValues[field.name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !value.isEmpty || field.required else { continue }
            dict[field.name] = converted(value, type: field.type)
        }
        return JSONValue.obj(dict)
    }

    private func converted(_ value: String, type: String) -> Any? {
        let lower = type.lowercased()
        if lower.contains("boolean") { return (JSONValue(any: value)).bool ?? ["true", "1", "yes", "on"].contains(value.lowercased()) }
        if lower.contains("integer") { return Int(value) ?? value }
        if lower.contains("number") { return Double(value) ?? value }
        if (lower.contains("array") || lower.contains("object")),
           let data = value.data(using: .utf8),
           let json = try? JSONDecoder().decode(JSONValue.self, from: data) {
            return json
        }
        return value
    }
}

private struct APIFieldEditor: View {
    let title: String
    let type: String
    let required: Bool
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                if required {
                    Text("必填").font(.caption2.weight(.bold)).foregroundStyle(Theme.accentWarm)
                }
                Spacer()
                Text(type).font(.caption2).foregroundStyle(.secondary)
            }
            TextField(title, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
        }
    }
}
