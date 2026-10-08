import Foundation

// MARK: - 错误类型
enum APIError: LocalizedError {
    case network(Error)
    case http(Int, String)
    case decoding(Error)
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .network(let e):       return "网络错误：\(e.localizedDescription)"
        case .http(let code, let msg): return "请求失败（\(code)）：\(msg)"
        case .decoding(let e):      return "数据解析失败：\(e.localizedDescription)"
        case .unauthorized:         return "请先登录"
        case .server(let msg):      return msg
        }
    }
}

// MARK: - API 响应结构（对应 tRPC 响应格式）
struct TRPCResponse<T: Decodable>: Decodable {
    let result: TRPCResult<T>?
    let error: TRPCError?
}

struct TRPCResult<T: Decodable>: Decodable {
    let data: TRPCData<T>?
}

struct TRPCData<T: Decodable>: Decodable {
    let json: T?
}

struct TRPCError: Decodable {
    let json: TRPCErrorDetail?
}

struct TRPCErrorDetail: Decodable {
    let message: String?
    let code: Int?
}

// MARK: - 超时包装（把「永不返回」的请求在 N 秒后变成可读错误，避免界面永远空白）
func withTimeout<T>(_ seconds: Double, _ op: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw APIError.server("加载超时，请检查网络后点按重试")
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - 分页参数
struct PageInput {
    var cursor: Int? = nil
    var limit: Int = 20
    var tagId: Int? = nil
    var sort: String? = nil
    var search: String? = nil
}

// MARK: - 通用 API 客户端
actor APIClient {
    static let shared = APIClient()

    // MARK: 生产环境地址（如需本地开发，改为 http://localhost:3000）
    private let baseURL = "https://mashangling.kimi.site"

    /// 自定义 URLSession，开启持久化 cookie 存储
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true   // 自动存储 Set-Cookie
        config.httpCookieStorage = HTTPCookieStorage.shared // 持久化到磁盘
        return URLSession(configuration: config)
    }()

    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "kimi_sid") }
        set { UserDefaults.standard.set(newValue, forKey: "kimi_sid") }
    }

    // MARK: GET 内存缓存（30 秒，返回页面秒开；任何写操作后整体失效）
    private var cache: [String: (data: Data, at: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    private func cached(_ key: String) -> Data? {
        guard let hit = cache[key], Date().timeIntervalSince(hit.at) < cacheTTL else { return nil }
        return hit.data
    }

    func setToken(_ token: String?) {
        authToken = token
    }

    func getToken() -> String? { authToken }

    // MARK: - 通用 GET（对应 tRPC query）
    func get<T: Decodable>(
        _ procedure: String,
        input: [String: Any]? = nil,
        cacheable: Bool = true
    ) async throws -> T {
        var urlStr = "\(baseURL)/api/trpc/\(procedure)"
        // tRPC 要求 input 包一层 {"json": ...}，即使为空也要传
        let wrapped: [String: Any] = ["json": input ?? [:]]
        let jsonData = try JSONSerialization.data(withJSONObject: wrapped)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        let encoded = jsonStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        urlStr += "?input=\(encoded)"
        guard let url = URL(string: urlStr) else { throw APIError.server("无效 URL") }

        if cacheable, let hit = cached(urlStr) {
            let decoded = try JSONDecoder().decode(TRPCResponse<T>.self, from: hit)
            if let result = decoded.result?.data?.json { return result }
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpShouldHandleCookies = true  // 让 URLSession 自动管理 Set-Cookie

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("无效响应") }

        if http.statusCode == 401 { throw APIError.unauthorized }

        if cacheable { cache[urlStr] = (data, Date()) }
        let decoded = try JSONDecoder().decode(TRPCResponse<T>.self, from: data)
        if let err = decoded.error?.json {
            throw APIError.server(err.message ?? "未知错误")
        }
        guard let result = decoded.result?.data?.json else {
            throw APIError.server("响应数据为空")
        }
        return result
    }

    // MARK: - 可空 GET（服务端 json 为 null 时返回 nil 而不是报错，如 auth.banInfo）
    func getOptional<T: Decodable>(
        _ procedure: String,
        input: [String: Any]? = nil
    ) async throws -> T? {
        var urlStr = "\(baseURL)/api/trpc/\(procedure)"
        let wrapped: [String: Any] = ["json": input ?? [:]]
        let jsonData = try JSONSerialization.data(withJSONObject: wrapped)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        let encoded = jsonStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        urlStr += "?input=\(encoded)"
        guard let url = URL(string: urlStr) else { throw APIError.server("无效 URL") }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpShouldHandleCookies = true

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("无效响应") }
        if http.statusCode == 401 { throw APIError.unauthorized }

        let decoded = try JSONDecoder().decode(TRPCResponse<T>.self, from: data)
        if let err = decoded.error?.json {
            throw APIError.server(err.message ?? "未知错误")
        }
        return decoded.result?.data?.json ?? nil
    }

    // MARK: - 通用 POST（对应 tRPC mutation）
    func post<T: Decodable>(
        _ procedure: String,
        input: [String: Any] = [:]
    ) async throws -> T {
        let urlStr = "\(baseURL)/api/trpc/\(procedure)"
        guard let url = URL(string: urlStr) else { throw APIError.server("无效 URL") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpShouldHandleCookies = true  // 让 URLSession 自动存储 Set-Cookie

        let body: [String: Any] = ["json": input]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        cache.removeAll()   // 写操作后读缓存整体失效

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("无效响应") }

        if http.statusCode == 401 { throw APIError.unauthorized }

        let decoded = try JSONDecoder().decode(TRPCResponse<T>.self, from: data)
        if let err = decoded.error?.json {
            throw APIError.server(err.message ?? "未知错误")
        }
        guard let result = decoded.result?.data?.json else {
            throw APIError.server("响应数据为空")
        }
        return result
    }

    // MARK: - 上传文件
    func upload<T: Decodable>(
        _ procedure: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        extraFields: [String: String] = [:]
    ) async throws -> T {
        let urlStr = "\(baseURL)/api/trpc/\(procedure)"
        guard let url = URL(string: urlStr) else { throw APIError.server("无效 URL") }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpShouldHandleCookies = true

        var body = Data()
        // extra fields
        for (key, value) in extraFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        cache.removeAll()   // 上传同样失效缓存

        let (data, _) = try await session.data(for: req)
        let decoded = try JSONDecoder().decode(TRPCResponse<T>.self, from: data)
        if let err = decoded.error?.json { throw APIError.server(err.message ?? "未知错误") }
        guard let result = decoded.result?.data?.json else { throw APIError.server("响应为空") }
        return result
    }
}
