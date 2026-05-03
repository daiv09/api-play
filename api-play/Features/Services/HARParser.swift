import Foundation

struct HARFile: Decodable {
    let log: HARLog
}

struct HARLog: Decodable {
    let entries: [HAREntry]
}

struct HAREntry: Decodable {
    let request: HARRequest
}

struct HARRequest: Decodable {
    let method: String
    let url: String
    let headers: [HARHeader]?
    let postData: HARPostData?
}

struct HARHeader: Decodable {
    let name: String
    let value: String
}

struct HARPostData: Decodable {
    let mimeType: String
    let text: String?
}

class HARParser {
    static func parse(url: URL) throws -> [APIRequest] {
        let data = try Data(contentsOf: url)
        let harFile = try JSONDecoder().decode(HARFile.self, from: data)
        
        var apiRequests: [APIRequest] = []
        for entry in harFile.log.entries {
            let reqData = entry.request
            
            // Generate a reasonable name from the URL path
            var name = "Imported Request"
            if let parsedURL = URL(string: reqData.url), let last = parsedURL.pathComponents.last, !last.isEmpty, last != "/" {
                name = last
            }
            
            let newReq = APIRequest(name: name)
            newReq.urlString = reqData.url
            newReq.httpMethod = HTTPMethod(rawValue: reqData.method.uppercased()) ?? .GET
            
            if let headers = reqData.headers {
                for h in headers {
                    // Ignore pseudo-headers from HTTP/2 (e.g., :authority, :method, :path)
                    if h.name.hasPrefix(":") { continue }
                    newReq.headers.append(KVPair(key: h.name, value: h.value, isEnabled: true))
                }
            }
            
            if let postData = reqData.postData, let text = postData.text {
                newReq.requestBody = text
            }
            
            apiRequests.append(newReq)
        }
        
        return apiRequests
    }
}
