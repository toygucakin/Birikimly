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
        
        return SimpleEntry(date: Date(), net: net, income: income, expense: expense, limit: limit)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let net: String
    let income: String
    let expense: String
    let limit: String
}

struct BirikimlyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aylık Net Durum")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(entry.net)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if !entry.limit.isEmpty {
                    Text("Aylık Limit: \(entry.limit)")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
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
