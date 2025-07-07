import Foundation

struct PropertyName: Decodable, Identifiable {
    let _id: String
    let name: String
    var id: String { _id }
}

struct Income: Identifiable, Decodable {
    let id: String
    let property_id: String
    let type: String
    let amount: Double
    let date: String
    let description: String?
    let is_recurring: Bool?
    let frequency: String?
    let recurrence_start_date: String?
    let recurrence_end_date: String?
}

struct Expense: Identifiable, Decodable {
    let id: String
    let property_id: String
    let type: String
    let amount: Double
    let date: String
    let description: String?
    let is_recurring: Bool?
    let frequency: String?
    let due_date: String?
    let is_paid: Bool?
    let payment_date: String?
    let recurrence_start_date: String?
    let recurrence_end_date: String?
} 