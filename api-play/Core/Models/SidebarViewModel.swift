import SwiftUI
import SwiftData

@Observable
class SidebarViewModel {
    var modelContext: ModelContext
    var isAddingFolder = false
    var isAddingEnv = false
    var newName = ""
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func addRequest(to folder: RequestFolder? = nil) -> APIRequest {
        let req = APIRequest(name: "New Request")
        req.folder = folder
        modelContext.insert(req)
        return req
    }
    
    func createFolder() {
        guard !newName.isEmpty else { return }
        let folder = RequestFolder(name: newName, order: 0)
        modelContext.insert(folder)
        newName = ""
    }
    
    func duplicate(_ request: APIRequest) -> APIRequest {
        let dup = APIRequest(name: "\(request.name) Copy")
        dup.urlString = request.urlString
        dup.httpMethod = request.httpMethod
        dup.folder = request.folder
        modelContext.insert(dup)
        return dup
    }
}
