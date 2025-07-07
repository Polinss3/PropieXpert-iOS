import Foundation

struct PropertyName: Decodable, Identifiable {
    let _id: String
    let name: String
    var id: String { _id }
} 