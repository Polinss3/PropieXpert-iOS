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

    enum CodingKeys: String, CodingKey {
        case id
        case property_id
        case type
        case initial_amount
        case years
        case interest_rate_fixed
        case interest_rate_variable
        case monthly_payment
        case start_date
        case end_date
        case bank_name
        case account_number
        case total_to_pay
        case payment_day
        case fixed_rate_period
        case reference_number
        case description
        case is_automatic_payment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Intenta decodificar 'id', si no existe usa 'property_id'
        if let id = try? container.decode(String.self, forKey: .id) {
            self.id = id
        } else {
            self.id = try container.decode(String.self, forKey: .property_id)
        }
        self.type = try container.decode(String.self, forKey: .type)
        self.initial_amount = try container.decode(Double.self, forKey: .initial_amount)
        self.years = try container.decode(Int.self, forKey: .years)
        self.interest_rate_fixed = try? container.decode(Double.self, forKey: .interest_rate_fixed)
        self.interest_rate_variable = try? container.decode(Double.self, forKey: .interest_rate_variable)
        self.monthly_payment = try container.decode(Double.self, forKey: .monthly_payment)
        self.start_date = try? container.decode(String.self, forKey: .start_date)
        self.end_date = try? container.decode(String.self, forKey: .end_date)
        self.bank_name = try? container.decode(String.self, forKey: .bank_name)
        self.account_number = try? container.decode(String.self, forKey: .account_number)
        self.total_to_pay = try? container.decode(Double.self, forKey: .total_to_pay)
        self.payment_day = try? container.decode(Int.self, forKey: .payment_day)
        self.fixed_rate_period = try? container.decode(Int.self, forKey: .fixed_rate_period)
        self.reference_number = try? container.decode(String.self, forKey: .reference_number)
        self.description = try? container.decode(String.self, forKey: .description)
        self.is_automatic_payment = try? container.decode(Bool.self, forKey: .is_automatic_payment)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(initial_amount, forKey: .initial_amount)
        try container.encode(years, forKey: .years)
        try container.encodeIfPresent(interest_rate_fixed, forKey: .interest_rate_fixed)
        try container.encodeIfPresent(interest_rate_variable, forKey: .interest_rate_variable)
        try container.encode(monthly_payment, forKey: .monthly_payment)
        try container.encodeIfPresent(start_date, forKey: .start_date)
        try container.encodeIfPresent(end_date, forKey: .end_date)
        try container.encodeIfPresent(bank_name, forKey: .bank_name)
        try container.encodeIfPresent(account_number, forKey: .account_number)
        try container.encodeIfPresent(total_to_pay, forKey: .total_to_pay)
        try container.encodeIfPresent(payment_day, forKey: .payment_day)
        try container.encodeIfPresent(fixed_rate_period, forKey: .fixed_rate_period)
        try container.encodeIfPresent(reference_number, forKey: .reference_number)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(is_automatic_payment, forKey: .is_automatic_payment)
    }
} 