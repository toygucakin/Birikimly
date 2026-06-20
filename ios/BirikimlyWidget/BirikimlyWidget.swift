import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), net: "₺0,00", income: "₺0,00", expense: "₺0,00", limit: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = getEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = getEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func getEntry() -> SimpleEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.example.birikimly")
        let net = userDefaults?.string(forKey: "net_amount") ?? "₺0,00"
        let income = userDefaults?.string(forKey: "income_amount") ?? "₺0,00"
        let expense = userDefaults?.string(forKey: "expense_amount") ?? "₺0,00"
        let limit = userDefaults?.string(forKey: "limit_amount") ?? ""
        let hasLimit = userDefaults?.bool(forKey: "has_limit") ?? false
        let expenseProgress = userDefaults?.integer(forKey: "expense_progress") ?? 0
        
        return SimpleEntry(date: Date(), net: net, income: income, expense: expense, limit: limit, hasLimit: hasLimit, expenseProgress: expenseProgress)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let net: String
    let income: String
    let expense: String
    let limit: String
    let hasLimit: Bool
    let expenseProgress: Int
}

struct BirikimlyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .center, spacing: 4) {
                Text("Aylık Net Durum")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(entry.net)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if entry.hasLimit {
                    Text("Aylık Limit: \(entry.limit)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.82))
                    
                    ProgressView(value: Double(entry.expenseProgress), total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1.0, green: 0.8, blue: 0.82)))
                        .frame(height: 4)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            HStack(spacing: 8) {
                Link(destination: URL(string: "birikimly://add_expense")!) {
                    VStack {
                        Text("Gider Ekle")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text(entry.expense)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(white: 0.2))
                    .cornerRadius(12)
                }
                
                Link(destination: URL(string: "birikimly://add_income")!) {
                    VStack {
                        Text("Gelir Ekle")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(entry.income)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(white: 0.2))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
    }
}

@main
struct BirikimlyWidget: Widget {
    let kind: String = "BirikimlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BirikimlyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Birikimly Özet")
        .description("Aylık bütçe durumunuzu ve hızlı ekleme butonlarını içerir.")
        .supportedFamilies([.systemMedium])
    }
}
