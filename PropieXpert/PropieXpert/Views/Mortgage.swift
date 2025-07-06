import Foundation

struct Mortgage: Identifiable, Codable {
    let id: String
    let type: String
    let initial_amount: Double
    let years: Int
    let interest_rate_fixed: Double?
    let interest_rate_variable: Double?
    let monthly_payment: Double
    let start_date: String?
    let end_date: String?
    let bank_name: String?
    let account_number: String?
    let total_to_pay: Double?
    let payment_day: Int?
    let fixed_rate_period: Int?
    let reference_number: String?
    let description: String?
    let is_automatic_payment: Bool?
    // ... otros campos si los necesitas
} 