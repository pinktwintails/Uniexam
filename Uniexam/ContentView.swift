//
//  ContentView.swift
//  Uniexam
//
//  Created by 岩崎未来 on 2026/07/23.
//

import SwiftUI

struct ContentView: View {
    @State private var schools: [ExamSchool]
    @State private var userDeviation: Double

    init() {
        _schools = State(initialValue: SchoolPersistence.load())
        _userDeviation = State(initialValue: UserProfilePersistence.loadDeviation())
    }

    var body: some View {
        TabView {
            SchoolListView(schools: $schools)
                .tabItem {
                    Label("志望校", systemImage: "building.columns")
                }

            ExamCalendarView(schools: schools)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }

            StrategyMapView(schools: schools, userDeviation: $userDeviation)
                .tabItem {
                    Label("戦略", systemImage: "chart.xyaxis.line")
                }
        }
        .tint(.uniexamIndigo)
        .onChange(of: schools) { _, newValue in
            SchoolPersistence.save(newValue)
        }
        .onChange(of: userDeviation) { _, newValue in
            UserProfilePersistence.saveDeviation(newValue)
        }
    }
}

struct ExamSchool: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var faculty: String
    var method: String
    var deviation: Double
    var color: SchoolColor
    var examDate: Date?
    var applicationStart: Date?
    var applicationEnd: Date?
    var paymentDeadline: Date?
    var requiredDocuments: String
    var resultDate: Date?
    var admissionFeeDeadline: Date?
    var tuitionDeadline: Date?
    var guidelineURL: String
    var passnaviURL: String
    var applicationURL: String
    var subjects: [SubjectScore]
    var minimumPassingScore: String
    var acceptanceRatio: String
    var capacity: String
    var memo: String

    var displayTitle: String {
        faculty.isEmpty ? name : "\(name) \(faculty)"
    }

    var deviationText: String {
        String(format: "%.1f", deviation)
    }

    var filledDetailItems: [DetailItem] {
        var items: [DetailItem] = []
        appendDate("入試日程", examDate, "calendar", &items)
        appendApplicationPeriod(&items)
        appendDate("入金締切", paymentDeadline, "yensign.circle", &items)
        appendText("出願に必要な書類", requiredDocuments, "folder", &items)
        appendDate("合格発表日", resultDate, "flag", &items)
        appendDate("入学金締切", admissionFeeDeadline, "graduationcap", &items)
        appendDate("授業料締切", tuitionDeadline, "creditcard", &items)
        appendURL("募集要項URL", guidelineURL, &items)
        appendURL("パスナビURL", passnaviURL, &items)
        appendURL("出願サイトURL", applicationURL, &items)
        if !subjects.isEmpty {
            items.append(DetailItem(title: "科目・配点", value: subjects.map(\.displayText).joined(separator: " / "), systemImage: "book"))
        }
        appendText("合格者最低点", minimumPassingScore, "target", &items)
        appendText("倍率", acceptanceRatio, "chart.bar", &items)
        appendText("募集人数", capacity, "person.3", &items)
        appendText("メモ", memo, "note.text", &items)
        return items
    }

    var events: [ExamEvent] {
        [
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .applicationStart, date: applicationStart, title: "出願開始"),
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .applicationEnd, date: applicationEnd, title: "出願締切"),
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .paymentDeadline, date: paymentDeadline, title: "入金締切"),
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .exam, date: examDate, title: "入試日程"),
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .result, date: resultDate, title: "合格発表"),
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .admissionFee, date: admissionFeeDeadline, title: "入学金締切"),
            ExamEvent(schoolID: id, schoolName: name, schoolColor: color, kind: .tuition, date: tuitionDeadline, title: "授業料締切")
        ].compactMap { $0.date == nil ? nil : $0 }
    }

    private func appendDate(_ title: String, _ date: Date?, _ image: String, _ items: inout [DetailItem]) {
        guard let date else { return }
        items.append(DetailItem(title: title, value: date.formatted(.examDate), systemImage: image))
    }

    private func appendApplicationPeriod(_ items: inout [DetailItem]) {
        guard applicationStart != nil || applicationEnd != nil else { return }
        items.append(
            DetailItem(
                title: "出願期間",
                value: Date.applicationPeriodText(start: applicationStart, end: applicationEnd),
                systemImage: "arrow.left.and.right",
                badge: Date.applicationPeriodDaysText(start: applicationStart, end: applicationEnd)
            )
        )
    }

    private func appendText(_ title: String, _ value: String, _ image: String, _ items: inout [DetailItem]) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.append(DetailItem(title: title, value: value, systemImage: image))
    }

    private func appendURL(_ title: String, _ value: String, _ items: inout [DetailItem]) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.append(DetailItem(title: title, value: value, systemImage: "link"))
    }
}

struct SubjectScore: Identifiable, Hashable, Codable {
    var id = UUID()
    var subject: String
    var score: String

    var displayText: String {
        score.isEmpty ? subject : "\(subject) \(score)"
    }
}

struct DetailItem: Identifiable {
    var title: String
    var value: String
    var systemImage: String
    var badge: String? = nil

    var id: String { title }
}

struct SchoolDetailSection: Identifiable {
    var title: String
    var systemImage: String
    var items: [DetailItem]

    var id: String { title }
}

struct ExamEvent: Identifiable, Hashable {
    var id = UUID()
    var schoolID: UUID
    var schoolName: String
    var schoolColor: SchoolColor
    var kind: EventKind
    var date: Date?
    var title: String

    var compactCalendarTitle: String {
        "\(kind.shortTitle) \(schoolName.replacingOccurrences(of: "大学", with: ""))"
    }
}

struct CalendarApplicationRange: Identifiable, Hashable {
    var id = UUID()
    var schoolID: UUID
    var schoolName: String
    var schoolColor: SchoolColor
    var startDate: Date
    var endDate: Date
    var lane: Int = 0

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return day >= start && day <= end
    }

    func isStart(_ date: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, inSameDayAs: startDate)
    }

    func isEnd(_ date: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, inSameDayAs: endDate)
    }
}

enum EventKind: String, CaseIterable, Identifiable, Codable {
    case all = "すべて"
    case applicationStart = "出願開始"
    case applicationEnd = "出願締切"
    case paymentDeadline = "入金締切"
    case exam = "入試日程"
    case result = "合格発表"
    case admissionFee = "入学金締切"
    case tuition = "授業料締切"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .applicationStart, .applicationEnd: "doc.text"
        case .paymentDeadline, .admissionFee, .tuition: "yensign.circle"
        case .exam: "pencil.and.list.clipboard"
        case .result: "flag"
        }
    }

    var shortTitle: String {
        switch self {
        case .all: "予定"
        case .applicationStart: "出願"
        case .applicationEnd: "締切"
        case .paymentDeadline: "入金"
        case .exam: "入試"
        case .result: "発表"
        case .admissionFee: "入学金"
        case .tuition: "授業料"
        }
    }
}

enum SchoolColor: String, CaseIterable, Identifiable, Codable {
    case blue
    case deepBlue
    case rosePink
    case brightRed
    case purple
    case violet
    case mint
    case teal
    case limeGreen
    case amber
    case orange
    case coral
    case skyBlue
    case turquoise
    case slate

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .schoolBlue
        case .deepBlue: .schoolDeepBlue
        case .rosePink: .schoolRosePink
        case .brightRed: .schoolBrightRed
        case .purple: .schoolPurple
        case .violet: .schoolViolet
        case .mint: .schoolMint
        case .teal: .schoolTeal
        case .limeGreen: .schoolLimeGreen
        case .amber: .schoolAmber
        case .orange: .schoolOrange
        case .coral: .schoolCoral
        case .skyBlue: .schoolSkyBlue
        case .turquoise: .schoolTurquoise
        case .slate: .schoolSlate
        }
    }

    var displayName: String {
        switch self {
        case .blue: "ロイヤルブルー"
        case .deepBlue: "ディープブルー"
        case .rosePink: "ローズピンク"
        case .brightRed: "ブライトレッド"
        case .purple: "パープル"
        case .violet: "バイオレット"
        case .mint: "エメラルド"
        case .teal: "ティール"
        case .limeGreen: "ライムグリーン"
        case .amber: "アンバー"
        case .orange: "オレンジ"
        case .coral: "コーラル"
        case .skyBlue: "スカイブルー"
        case .turquoise: "ターコイズ"
        case .slate: "スレート"
        }
    }

    var hexCode: String {
        switch self {
        case .blue: "#6B8FF3"
        case .deepBlue: "#4E7CE2"
        case .rosePink: "#F28AAE"
        case .brightRed: "#FF6B6B"
        case .purple: "#A78BFA"
        case .violet: "#B79AF9"
        case .mint: "#4DCCA1"
        case .teal: "#40C4C9"
        case .limeGreen: "#B7D957"
        case .amber: "#F6C453"
        case .orange: "#FFB266"
        case .coral: "#FF8F8F"
        case .skyBlue: "#7BC0F8"
        case .turquoise: "#5ED6E0"
        case .slate: "#A6B2C7"
        }
    }
}

struct AppTopBar: View {
    var title: String
    var subtitle: String? = nil
    var leadingSystemImage: String? = nil
    var trailingSystemImage: String? = nil
    var leadingAction: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            barButton(systemImage: leadingSystemImage, action: leadingAction)

            VStack(alignment: .center, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(maxWidth: .infinity)

            barButton(systemImage: trailingSystemImage, action: trailingAction)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.deepNavy)
    }

    @ViewBuilder
    private func barButton(systemImage: String?, action: (() -> Void)?) -> some View {
        if let systemImage {
            Button {
                action?()
            } label: {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(action == nil)
            .opacity(action == nil ? 0.86 : 1)
        } else {
            Color.clear
                .frame(width: 38, height: 38)
        }
    }
}

struct SchoolListView: View {
    @Binding var schools: [ExamSchool]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(title: "志望校", trailingSystemImage: "plus", trailingAction: {
                    showingAddSheet = true
                })

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach($schools) { $school in
                            NavigationLink {
                                SchoolDetailView(school: $school)
                            } label: {
                                SchoolRow(school: school)
                            }
                            .buttonStyle(.plain)
                        }

                        if schools.isEmpty {
                            ContentUnavailableView("志望校がまだありません", systemImage: "building.columns", description: Text("右上の追加ボタンから学校と方式を登録できます。"))
                                .padding(.top, 72)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .background(Color.appBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                EditSchoolView(mode: .add, school: .blank(nextColor: SchoolColor.allCases[schools.count % SchoolColor.allCases.count])) { newSchool in
                    schools.append(newSchool)
                }
            }
        }
    }
}

struct SchoolRow: View {
    var school: ExamSchool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                SchoolMonogram(school: school)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(school.name)
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                    }

                    Text("\(school.faculty.isEmpty ? "学部未入力" : school.faculty)  |  \(school.method)  |  偏差値 \(school.deviationText)")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(16)

            Divider()
                .padding(.leading, 16)

            HStack(spacing: 10) {
                Image(systemName: nextEvent(for: school)?.kind.icon ?? "calendar")
                    .foregroundStyle(school.color.color)
                Text(nextEvent(for: school)?.title ?? "次の予定なし")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(school.color.color)
                Spacer()
                Text(nextEvent(for: school)?.date?.formatted(.monthDayWeekday) ?? "-")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(school.color.color)
                .frame(width: 4)
        }
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func nextEvent(for school: ExamSchool) -> ExamEvent? {
        school.events
            .compactMap { event -> ExamEvent? in
                guard let date = event.date, date >= .demoToday else { return nil }
                return event
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            .first
    }
}

struct SchoolDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var school: ExamSchool
    @State private var showingEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "詳細",
                subtitle: school.name,
                leadingSystemImage: "chevron.left",
                trailingSystemImage: "square.and.pencil",
                leadingAction: { dismiss() },
                trailingAction: { showingEditSheet = true }
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    SchoolDetailSummary(school: school)

                    if let nextEvent {
                        NextExamEventBanner(event: nextEvent, tint: school.color.color)
                    }

                    HStack {
                        Text("登録済み情報")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        Text("\(registeredItemCount)項目")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding(.top, 4)

                    ForEach(detailSections) { section in
                        SchoolDetailSectionCard(section: section, tint: school.color.color)
                    }

                    if detailSections.isEmpty {
                        Button {
                            showingEditSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("詳しい情報を追加")
                                        .font(.subheadline.weight(.bold))
                                    Text("日程や出願情報を登録すると、ここに整理して表示されます")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(school.color.color)
                            .padding(16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingEditSheet) {
            EditSchoolView(mode: .edit, school: school) { updatedSchool in
                school = updatedSchool
            }
        }
    }

    private var nextEvent: ExamEvent? {
        school.events
            .filter { ($0.date ?? .distantPast) >= .demoToday }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            .first
    }

    private var registeredItemCount: Int {
        detailSections.reduce(0) { $0 + $1.items.count }
    }

    private var detailSections: [SchoolDetailSection] {
        [
            SchoolDetailSection(title: "日程", systemImage: "calendar", items: scheduleItems),
            SchoolDetailSection(title: "出願情報", systemImage: "doc.text.fill", items: applicationItems),
            SchoolDetailSection(title: "試験情報", systemImage: "pencil.and.list.clipboard", items: examItems),
            SchoolDetailSection(title: "メモ", systemImage: "note.text", items: noteItems)
        ].filter { !$0.items.isEmpty }
    }

    private var scheduleItems: [DetailItem] {
        [
            dateItem("入試日程", school.examDate, "pencil.and.list.clipboard"),
            applicationPeriodItem,
            dateItem("入金締切", school.paymentDeadline, "yensign.circle"),
            dateItem("合格発表日", school.resultDate, "flag.fill"),
            dateItem("入学金締切", school.admissionFeeDeadline, "graduationcap.fill"),
            dateItem("授業料締切", school.tuitionDeadline, "creditcard.fill")
        ].compactMap { $0 }
    }

    private var applicationPeriodItem: DetailItem? {
        guard school.applicationStart != nil || school.applicationEnd != nil else { return nil }
        return DetailItem(
            title: "出願期間",
            value: Date.applicationPeriodText(start: school.applicationStart, end: school.applicationEnd),
            systemImage: "arrow.left.and.right",
            badge: Date.applicationPeriodDaysText(start: school.applicationStart, end: school.applicationEnd)
        )
    }

    private var applicationItems: [DetailItem] {
        [
            textItem("必要書類", school.requiredDocuments, "folder.fill"),
            textItem("募集要項", school.guidelineURL, "link"),
            textItem("パスナビ", school.passnaviURL, "link"),
            textItem("出願サイト", school.applicationURL, "link")
        ].compactMap { $0 }
    }

    private var examItems: [DetailItem] {
        var items: [DetailItem] = []
        if !school.subjects.isEmpty {
            items.append(
                DetailItem(
                    title: "科目・配点",
                    value: school.subjects.map(\.displayText).joined(separator: " / "),
                    systemImage: "book.closed.fill"
                )
            )
        }
        items.append(contentsOf: [
            textItem("合格者最低点", school.minimumPassingScore, "target"),
            textItem("倍率", school.acceptanceRatio, "chart.bar.fill"),
            textItem("募集人数", school.capacity, "person.3.fill")
        ].compactMap { $0 })
        return items
    }

    private var noteItems: [DetailItem] {
        [textItem("メモ", school.memo, "square.and.pencil")].compactMap { $0 }
    }

    private func dateItem(_ title: String, _ date: Date?, _ systemImage: String) -> DetailItem? {
        guard let date else { return nil }
        return DetailItem(title: title, value: date.formatted(.examDate), systemImage: systemImage)
    }

    private func textItem(_ title: String, _ value: String, _ systemImage: String) -> DetailItem? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return DetailItem(title: title, value: value, systemImage: systemImage)
    }
}

struct DetailInfoRow: View {
    var item: DetailItem
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)

                if item.systemImage == "link", let url = URL(string: item.value) {
                    Link(destination: url) {
                        HStack(spacing: 5) {
                            Text(item.value)
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    }
                } else {
                    Text(item.value)
                        .font(.subheadline.weight(item.title.contains("締切") || item.title == "入試日程" || item.title == "出願期間" ? .semibold : .regular))
                        .foregroundStyle(Color.primaryText)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)

            if let badge = item.badge {
                Text(badge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

struct SchoolDetailSummary: View {
    var school: ExamSchool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(school.color.color)
                .frame(height: 5)

            HStack(alignment: .top, spacing: 14) {
                SchoolMonogram(school: school)

                VStack(alignment: .leading, spacing: 5) {
                    Text(school.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primaryText)
                    Text(school.faculty)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    Label(school.method, systemImage: "list.clipboard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                }

                Spacer(minLength: 8)

                VStack(spacing: 2) {
                    Text("偏差値")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    Text(school.deviationText)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(school.color.color)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(school.color.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(16)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct NextExamEventBanner: View {
    var event: ExamEvent
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.kind.icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text("次の予定")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Text(event.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
            }

            Spacer()

            Text(event.date?.formatted(.monthDayWeekday) ?? "-")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.primaryText)
        }
        .padding(14)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SchoolDetailSectionCard: View {
    var section: SchoolDetailSection
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: section.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Text(section.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(section.items.count)項目")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()

            ForEach(section.items) { item in
                DetailInfoRow(item: item, tint: tint)
                if item.id != section.items.last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EditSchoolView: View {
    enum Mode {
        case add
        case edit
    }

    private enum EditorSection: Hashable {
        case schedule
        case application
        case exam
        case notes
    }

    private enum FocusedField: Hashable {
        case name
        case method
        case faculty
    }

    @Environment(\.dismiss) private var dismiss
    var mode: Mode
    @State var school: ExamSchool
    @State private var expandedSections: Set<EditorSection> = []
    @FocusState private var focusedField: FocusedField?
    var onSave: (ExamSchool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorProgressHeader(
                        completedRequiredCount: completedRequiredCount,
                        optionalFieldCount: optionalFieldCount,
                        tint: school.color.color
                    )
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                }

                Section {
                    EditorTextField(
                        title: "学校名",
                        placeholder: "例：青葉大学",
                        systemImage: "building.columns.fill",
                        text: $school.name,
                        isRequired: true
                    )
                    .focused($focusedField, equals: .name)

                    EditorTextField(
                        title: "入試方式",
                        placeholder: "例：一般A・共通テスト利用",
                        systemImage: "list.clipboard.fill",
                        text: $school.method,
                        isRequired: true
                    )
                    .focused($focusedField, equals: .method)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            EditorFieldLabel(title: "偏差値", systemImage: "chart.line.uptrend.xyaxis", isRequired: true)
                            Spacer()
                            Text(school.deviation, format: .number.precision(.fractionLength(1)))
                                .font(.headline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.deepNavy)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(school.color.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                        }
                        Slider(value: $school.deviation, in: 35...80, step: 0.5)
                            .tint(school.color.color)
                    }
                    .padding(.vertical, 4)

                    EditorTextField(
                        title: "学部・学科",
                        placeholder: "例：経済学部 経済学科",
                        systemImage: "graduationcap.fill",
                        text: $school.faculty,
                        isRequired: true
                    )
                    .focused($focusedField, equals: .faculty)

                    VStack(alignment: .leading, spacing: 12) {
                        EditorFieldLabel(title: "大学カラー", systemImage: "paintpalette.fill", isRequired: true)
                        SchoolColorPicker(selection: $school.color)
                    }
                } header: {
                    Text("必須項目")
                } footer: {
                    if completedRequiredCount < 5 {
                        Label("学校名・入試方式・学部学科を入力すると保存できます", systemImage: "info.circle")
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                editorSection(
                    section: .schedule,
                    title: "日程",
                    subtitle: "入試・発表・支払いの期日",
                    systemImage: "calendar",
                    completedCount: scheduleCount
                ) {
                    OptionalDatePicker(title: "入試日程", date: $school.examDate)
                    ApplicationPeriodPicker(startDate: $school.applicationStart, endDate: $school.applicationEnd)
                    OptionalDatePicker(title: "入金締切", date: $school.paymentDeadline)
                    OptionalDatePicker(title: "合格発表日", date: $school.resultDate)
                    OptionalDatePicker(title: "入学金締切", date: $school.admissionFeeDeadline)
                    OptionalDatePicker(title: "授業料締切", date: $school.tuitionDeadline)
                }

                editorSection(
                    section: .application,
                    title: "出願情報",
                    subtitle: "必要書類と関連リンク",
                    systemImage: "doc.text.fill",
                    completedCount: applicationInformationCount
                ) {
                    EditorTextField(
                        title: "必要書類",
                        placeholder: "調査書、写真、志望理由書など",
                        systemImage: "folder.fill",
                        text: $school.requiredDocuments,
                        axis: .vertical
                    )
                    EditorTextField(title: "募集要項URL", placeholder: "https://", systemImage: "link", text: $school.guidelineURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    EditorTextField(title: "パスナビURL", placeholder: "https://", systemImage: "link", text: $school.passnaviURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    EditorTextField(title: "出願サイトURL", placeholder: "https://", systemImage: "link", text: $school.applicationURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                editorSection(
                    section: .exam,
                    title: "試験情報",
                    subtitle: "科目・配点と過去の実績",
                    systemImage: "pencil.and.list.clipboard",
                    completedCount: examInformationCount
                ) {
                    SubjectEditor(subjects: $school.subjects)
                    EditorTextField(title: "合格者最低点", placeholder: "例：320 / 500", systemImage: "target", text: $school.minimumPassingScore)
                    EditorTextField(title: "倍率", placeholder: "例：3.2倍", systemImage: "chart.bar.fill", text: $school.acceptanceRatio)
                    EditorTextField(title: "募集人数", placeholder: "例：80人", systemImage: "person.3.fill", text: $school.capacity)
                }

                editorSection(
                    section: .notes,
                    title: "メモ",
                    subtitle: "気づいたことを自由に記録",
                    systemImage: "note.text",
                    completedCount: notesCount
                ) {
                    EditorTextField(
                        title: "メモ",
                        placeholder: "キャンパス、過去問、対策など",
                        systemImage: "square.and.pencil",
                        text: $school.memo,
                        axis: .vertical
                    )
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mode == .add ? "志望校を追加" : "志望校を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(school)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        school.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || school.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || school.faculty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                if mode == .add {
                    focusedField = .name
                }
            }
        }
    }

    @ViewBuilder
    private func editorSection<Content: View>(
        section: EditorSection,
        title: String,
        subtitle: String,
        systemImage: String,
        completedCount: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: section)) {
                content()
                    .padding(.top, 8)
            } label: {
                EditorSectionHeader(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage,
                    completedCount: completedCount,
                    tint: school.color.color
                )
            }
            .tint(Color.secondaryText)
        }
    }

    private func expansionBinding(for section: EditorSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    private var completedRequiredCount: Int {
        [
            !school.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !school.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !school.faculty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            true,
            true
        ].filter { $0 }.count
    }

    private var scheduleCount: Int {
        let dateCount = [
            school.examDate,
            school.paymentDeadline,
            school.resultDate,
            school.admissionFeeDeadline,
            school.tuitionDeadline
        ].compactMap { $0 }.count
        let applicationPeriodCount = school.applicationStart != nil || school.applicationEnd != nil ? 1 : 0
        return dateCount + applicationPeriodCount
    }

    private var applicationInformationCount: Int {
        nonEmptyCount([
            school.requiredDocuments,
            school.guidelineURL,
            school.passnaviURL,
            school.applicationURL
        ])
    }

    private var examInformationCount: Int {
        (school.subjects.isEmpty ? 0 : 1) + nonEmptyCount([
            school.minimumPassingScore,
            school.acceptanceRatio,
            school.capacity
        ])
    }

    private var notesCount: Int {
        nonEmptyCount([school.memo])
    }

    private var optionalFieldCount: Int {
        scheduleCount + applicationInformationCount + examInformationCount + notesCount
    }

    private func nonEmptyCount(_ values: [String]) -> Int {
        values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

struct OptionalDatePicker: View {
    var title: String
    @Binding var date: Date?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.primaryText)
            Spacer(minLength: 8)

            if let unwrappedDate = date {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { unwrappedDate },
                        set: { date = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ja_JP"))

                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title)を削除")
            } else {
                Button {
                    date = .demoToday
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }
}

struct ApplicationPeriodPicker: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("出願期間")
                    .font(.subheadline)
                    .foregroundStyle(Color.primaryText)

                Spacer(minLength: 8)

                if let daysText = Date.applicationPeriodDaysText(start: startDate, end: endDate) {
                    Text(daysText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.uniexamIndigo)
                        .monospacedDigit()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.uniexamIndigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }

                if startDate == nil && endDate == nil {
                    Button {
                        startDate = .demoToday
                        endDate = Calendar.current.date(byAdding: .day, value: 13, to: .demoToday) ?? .demoToday
                    } label: {
                        Label("追加", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        startDate = nil
                        endDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondaryText.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("出願期間を削除")
                }
            }

            if startDate != nil || endDate != nil {
                VStack(spacing: 8) {
                    periodDateRow(title: "開始", date: $startDate)
                    periodDateRow(title: "締切", date: $endDate)
                }
                .padding(10)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(.vertical, 3)
    }

    private func periodDateRow(title: String, date: Binding<Date?>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
                .frame(width: 34, alignment: .leading)

            Spacer(minLength: 8)

            if let unwrappedDate = date.wrappedValue {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { unwrappedDate },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            } else {
                Button {
                    date.wrappedValue = .demoToday
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SubjectEditor: View {
    @Binding var subjects: [SubjectScore]
    @State private var newSubject = ""
    @State private var newScore = ""

    var body: some View {
        EditorFieldLabel(title: "科目ごとの配点", systemImage: "book.closed.fill")

        ForEach($subjects) { $subject in
            HStack(spacing: 10) {
                TextField("科目名", text: $subject.subject)
                    .textFieldStyle(.roundedBorder)
                TextField("配点", text: $subject.score)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Button {
                    if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
                        subjects.remove(at: index)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Color.schoolCoral)
                }
                .buttonStyle(.plain)
            }
        }

        HStack(spacing: 10) {
            TextField("科目を追加", text: $newSubject)
                .textFieldStyle(.roundedBorder)
            TextField("配点", text: $newScore)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Button {
                subjects.append(SubjectScore(subject: newSubject, score: newScore))
                newSubject = ""
                newScore = ""
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(newSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct EditorProgressHeader: View {
    private let requiredFieldCount = 5

    var completedRequiredCount: Int
    var optionalFieldCount: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(completedRequiredCount) / CGFloat(requiredFieldCount))
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: completedRequiredCount == requiredFieldCount ? "checkmark" : "pencil")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(completedRequiredCount == requiredFieldCount ? "保存の準備ができました" : "まず必須項目を入力")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                Text("必須 \(completedRequiredCount)/\(requiredFieldCount) ・ 任意 \(optionalFieldCount)項目入力済み")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

struct EditorFieldLabel: View {
    var title: String
    var systemImage: String
    var isRequired = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.uniexamIndigo)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primaryText)
            if isRequired {
                Text("必須")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.schoolCoral)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.schoolCoral.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

struct EditorTextField: View {
    var title: String
    var placeholder: String
    var systemImage: String
    @Binding var text: String
    var isRequired = false
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(title: title, systemImage: systemImage, isRequired: isRequired)
            TextField(placeholder, text: $text, axis: axis)
                .font(.body)
                .lineLimit(axis == .vertical ? 2...6 : 1...1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondaryText.opacity(0.18), lineWidth: 1)
                }
        }
        .padding(.vertical, 3)
    }
}

struct EditorSectionHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var completedCount: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 4)
            if completedCount > 0 {
                Text("\(completedCount)件")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 3)
    }
}

struct SchoolColorPicker: View {
    @Binding var selection: SchoolColor
    @State private var isExpanded = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(selection.color)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        }
                        .shadow(color: selection.color.opacity(0.35), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Text(selection.hexCode)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selection.color.opacity(0.35), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("大学カラー")
            .accessibilityValue("\(selection.displayName) \(selection.hexCode)")
            .accessibilityHint(isExpanded ? "閉じる" : "色を選ぶ")

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(SchoolColor.allCases) { color in
                        Button {
                            selection = color
                            withAnimation(.snappy(duration: 0.2)) {
                                isExpanded = false
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.color)
                                if selection == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 34, height: 34)
                            .overlay {
                                Circle()
                                    .stroke(selection == color ? Color.deepNavy : .clear, lineWidth: 2)
                                    .padding(-3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.displayName)
                        .accessibilityValue(color.hexCode)
                        .accessibilityAddTraits(selection == color ? .isSelected : [])
                    }
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct ExamCalendarView: View {
    var schools: [ExamSchool]
    @State private var selectedDate = Date.from(year: 2027, month: 2, day: 6)
    @State private var displayedMonth = Date.from(year: 2027, month: 2, day: 1)
    @State private var selectedKind: EventKind = .all
    @State private var selectedSchoolID: UUID?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(title: "カレンダー", trailingSystemImage: "line.3.horizontal.decrease.circle")

                filterBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        MonthGridView(
                            monthStart: displayedMonth,
                            selectedDate: $selectedDate,
                            events: filteredEvents,
                            applicationRanges: visibleApplicationRanges,
                            onPreviousMonth: { moveMonth(by: -1) },
                            onNextMonth: { moveMonth(by: 1) }
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(selectedDate.formatted(.monthDayWeekday))
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text("\(events(on: selectedDate).count)件")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                            }

                            if events(on: selectedDate).isEmpty {
                                Text("この日の予定はありません。")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                                    .padding(.vertical, 16)
                            } else {
                                ForEach(events(on: selectedDate)) { event in
                                    CalendarEventRow(event: event, school: schools.first { $0.id == event.schoolID })
                                }
                            }
                        }
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)
                }
                .background(Color.appBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "すべて", isSelected: selectedKind == .all && selectedSchoolID == nil) {
                    selectedKind = .all
                    selectedSchoolID = nil
                }

                FilterChip(title: "入試日程", isSelected: selectedKind == .exam) {
                    selectedKind = .exam
                }

                FilterChip(title: "締切のみ", isSelected: selectedKind == .applicationEnd) {
                    selectedKind = .applicationEnd
                }

                ForEach(schools) { school in
                    FilterChip(title: school.name, color: school.color.color, isSelected: selectedSchoolID == school.id) {
                        selectedSchoolID = selectedSchoolID == school.id ? nil : school.id
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .background(.white)
    }

    private var filteredEvents: [ExamEvent] {
        schools.flatMap(\.events)
            .filter { event in
                let kindMatches = selectedKind == .all || event.kind == selectedKind
                let schoolMatches = selectedSchoolID == nil || event.schoolID == selectedSchoolID
                return kindMatches && schoolMatches
            }
    }

    private var visibleApplicationRanges: [CalendarApplicationRange] {
        guard selectedKind == .all || selectedKind == .applicationStart || selectedKind == .applicationEnd else {
            return []
        }

        let ranges = schools.compactMap { school -> CalendarApplicationRange? in
            guard selectedSchoolID == nil || selectedSchoolID == school.id else { return nil }
            guard let startDate = school.applicationStart, let endDate = school.applicationEnd else { return nil }
            return CalendarApplicationRange(
                schoolID: school.id,
                schoolName: school.name,
                schoolColor: school.color,
                startDate: startDate,
                endDate: endDate
            )
        }

        return assignApplicationRangeLanes(to: ranges)
    }

    private func events(on date: Date) -> [ExamEvent] {
        filteredEvents
            .filter { event in
                guard let eventDate = event.date else { return false }
                return calendar.isDate(eventDate, inSameDayAs: date)
            }
            .sorted { $0.title < $1.title }
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) ?? newMonth
        selectedDate = displayedMonth
    }

    private func assignApplicationRangeLanes(to ranges: [CalendarApplicationRange]) -> [CalendarApplicationRange] {
        var laneEndDates: [Date] = []

        return ranges
            .sorted { $0.startDate < $1.startDate }
            .map { range in
                var rangeWithLane = range
                let laneIndex = laneEndDates.firstIndex { endDate in
                    calendar.startOfDay(for: endDate) < calendar.startOfDay(for: range.startDate)
                }

                if let laneIndex {
                    rangeWithLane.lane = laneIndex
                    laneEndDates[laneIndex] = range.endDate
                } else {
                    rangeWithLane.lane = laneEndDates.count
                    laneEndDates.append(range.endDate)
                }

                return rangeWithLane
            }
    }
}

struct MonthGridView: View {
    var monthStart: Date
    @Binding var selectedDate: Date
    var events: [ExamEvent]
    var applicationRanges: [CalendarApplicationRange]
    var onPreviousMonth: () -> Void
    var onNextMonth: () -> Void

    private let calendar = Calendar.current
    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                }

                Spacer()
                Text(monthStart.formatted(.yearMonth))
                    .font(.title2.weight(.bold))
                Spacer()

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(weekday == "日" ? .red : .secondaryText)
                        .frame(height: 24)
                }

                ForEach(calendarDates, id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        CalendarDayCell(
                            date: date,
                            isCurrentMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            events: eventsForDay(date),
                            applicationRanges: applicationRangesForDay(date)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var calendarDates: [Date] {
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let mondayBasedOffset = (firstWeekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayBasedOffset, to: monthStart) ?? monthStart
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func eventsForDay(_ date: Date) -> [ExamEvent] {
        events.filter { event in
            guard let eventDate = event.date else { return false }
            guard event.kind != .applicationStart && event.kind != .applicationEnd else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }

    private func applicationRangesForDay(_ date: Date) -> [CalendarApplicationRange] {
        applicationRanges.filter { $0.contains(date, calendar: calendar) }
    }
}

struct CalendarDayCell: View {
    var date: Date
    var isCurrentMonth: Bool
    var isSelected: Bool
    var events: [ExamEvent]
    var applicationRanges: [CalendarApplicationRange]

    private var cellBackground: Color {
        let hasExam = events.contains { $0.kind == .exam }
        let hasResult = events.contains { $0.kind == .result }

        switch (hasExam, hasResult) {
        case (true, true):
            return Color.schoolTeal.opacity(0.20)
        case (true, false):
            return Color.clearBlue.opacity(0.24)
        case (false, true):
            return Color.schoolMint.opacity(0.24)
        case (false, false):
            return isSelected ? Color.uniexamIndigo.opacity(0.08) : Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color.uniexamIndigo.opacity(0.34)
        }

        if events.contains(where: { $0.kind == .exam || $0.kind == .result }) {
            return Color.uniexamIndigo.opacity(0.16)
        }

        return Color.secondaryText.opacity(0.08)
    }

    private var visibleRangeLaneCount: Int {
        min((applicationRanges.map(\.lane).max() ?? -1) + 1, 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : (isCurrentMonth ? Color.primaryText : Color.secondaryText.opacity(0.45)))
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.uniexamIndigo : Color.clear, in: Circle())
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(events.prefix(2)) { event in
                    Text(event.compactCalendarTitle)
                        .font(.system(size: 8.5, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(event.schoolColor.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(event.schoolColor.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                let hiddenCount = max(applicationRanges.count - visibleRangeLaneCount, 0) + max(events.count - 2, 0)
                if hiddenCount > 0 {
                    Text("+\(hiddenCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 0)

                ForEach(0..<visibleRangeLaneCount, id: \.self) { lane in
                    if let range = applicationRanges.first(where: { $0.lane == lane }) {
                        ApplicationRangeRibbon(range: range, date: date)
                    } else {
                        Color.clear
                            .frame(height: 7)
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(height: 76)
        .background {
            cellBackground
            Rectangle()
                .stroke(borderColor, lineWidth: 0.7)
        }
    }
}

struct ApplicationRangeRibbon: View {
    var range: CalendarApplicationRange
    var date: Date

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if range.isStart(date, calendar: calendar) {
                    Image(systemName: "arrowtriangle.left.fill")
                        .font(.system(size: 4.5, weight: .bold))
                }

                Rectangle()
                    .frame(height: 1.5)

                if range.isEnd(date, calendar: calendar) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 4.5, weight: .bold))
                }
            }
            .foregroundStyle(range.schoolColor.color)

            if range.isStart(date, calendar: calendar) || range.isEnd(date, calendar: calendar) {
                Text(range.isStart(date, calendar: calendar) ? "出願" : "締切")
                    .font(.system(size: 6, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(range.schoolColor.color)
                    .padding(.horizontal, 2)
                    .background(.white.opacity(0.82), in: Capsule())
            }
        }
        .padding(.horizontal, -2)
        .frame(height: 7)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(range.schoolName) 出願期間")
    }
}

struct CalendarEventRow: View {
    var event: ExamEvent
    var school: ExamSchool?

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(event.schoolColor.color)
                .frame(width: 10, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.schoolName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(event.schoolColor.color)
                Text("\(school?.faculty ?? "") \(school?.method ?? "") \(event.title)")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                if let school {
                    Text("偏差値 \(school.deviationText)")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Spacer()
            Image(systemName: event.kind.icon)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical, 10)
    }
}

struct StrategyMapView: View {
    var schools: [ExamSchool]
    @Binding var userDeviation: Double
    @State private var selectedFilter = "すべて"
    @State private var chartZoomScale = 1.0
    @State private var committedChartZoomScale = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(title: "戦略マップ")

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        UserDeviationEditor(userDeviation: $userDeviation)

                        HStack(spacing: 8) {
                            ForEach(["すべて", "国公立", "私立", "お気に入り"], id: \.self) { filter in
                                FilterChip(title: filter, isSelected: selectedFilter == filter) {
                                    selectedFilter = filter
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("入試日 × 偏差値")
                                .font(.headline)
                            Text("横軸は2月の日付、縦軸は偏差値。ピンチで縦軸を拡大できます。")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                StrategyChart(schools: schools, userDeviation: userDeviation, yZoomScale: chartZoomScale)
                                    .frame(width: 860, height: 390)
                                    .padding(.trailing, 12)
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                chartZoomScale = min(max(committedChartZoomScale * value, 1.0), 3.5)
                                            }
                                            .onEnded { value in
                                                chartZoomScale = min(max(committedChartZoomScale * value, 1.0), 3.5)
                                                committedChartZoomScale = chartZoomScale
                                            }
                                    )
                            }
                            .padding(.top, 8)
                        }
                        .padding(16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 0) {
                            Text("今月のポイント")
                                .font(.headline)
                                .padding(16)

                            InsightRow(icon: "list.number", title: "受験順", detail: recommendedOrder)
                            Divider().padding(.leading, 56)
                            InsightRow(icon: "shield.checkered", title: "安全校", detail: safetySchoolText)
                            Divider().padding(.leading, 56)
                            InsightRow(icon: "exclamationmark.triangle", title: "連続日程注意", detail: "2日連続の入試がある場合はここで確認")
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(18)
                }
                .background(Color.appBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var examSchools: [ExamSchool] {
        schools.filter { $0.examDate != nil }.sorted { ($0.examDate ?? .distantFuture) < ($1.examDate ?? .distantFuture) }
    }

    private var recommendedOrder: String {
        examSchools.enumerated().map { index, school in
            "\(index + 1). \(school.examDate?.formatted(.shortMonthDay) ?? "-") \(school.name)"
        }.joined(separator: "  ")
    }

    private var safetySchoolText: String {
        guard let school = examSchools.min(by: { $0.deviation < $1.deviation }) else { return "未登録" }
        return "\(school.name) 偏差値\(school.deviationText)"
    }
}

struct UserDeviationEditor: View {
    @Binding var userDeviation: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自分の偏差値")
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Text("仮置き。あとでプロフィールや設定に移せます。")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                Text(String(format: "%.1f", userDeviation))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.uniexamIndigo)
            }

            Slider(value: $userDeviation, in: 35...80, step: 0.5)
                .tint(.uniexamIndigo)

            HStack {
                Text("35")
                Spacer()
                Text("目安ラインとして戦略マップに表示")
                Spacer()
                Text("80")
            }
            .font(.caption2)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StrategyChart: View {
    var schools: [ExamSchool]
    var userDeviation: Double
    var yZoomScale: Double

    private let fullMinDeviation = 30.0
    private let fullMaxDeviation = 75.0

    private var visibleDeviationRange: ClosedRange<Double> {
        let fullSpan = fullMaxDeviation - fullMinDeviation
        let visibleSpan = fullSpan / min(max(yZoomScale, 1.0), 3.5)
        let halfSpan = visibleSpan / 2
        let center = min(max(userDeviation, fullMinDeviation + halfSpan), fullMaxDeviation - halfSpan)
        return (center - halfSpan)...(center + halfSpan)
    }

    var body: some View {
        GeometryReader { proxy in
            let plot = CGRect(x: 42, y: 20, width: proxy.size.width - 58, height: proxy.size.height - 58)

            ZStack(alignment: .topLeading) {
                schoolLevelBands(in: plot)
                grid(in: plot)
                userDeviationLine(in: plot)

                ForEach(schools.filter { $0.examDate != nil }) { school in
                    if let date = school.examDate {
                        let day = Calendar.current.component(.day, from: date)
                        let x = plot.minX + plot.width * CGFloat(Double(day - 1) / 27.0)
                        let range = visibleDeviationRange
                        let y = yPosition(for: school.deviation, in: plot)

                        if range.contains(school.deviation) {
                            VStack(spacing: 4) {
                                Text("\(date.formatted(.shortMonthDay)) \(school.name)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(school.color.color)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background {
                                        Capsule()
                                            .fill(.white)
                                        Capsule()
                                            .fill(school.color.color.opacity(0.12))
                                    }
                                    .overlay(Capsule().stroke(school.color.color.opacity(0.45), lineWidth: 1))
                                Circle()
                                    .fill(school.color.color)
                                    .frame(width: 11, height: 11)
                            }
                            .position(x: x, y: y - 18)
                        }
                    }
                }
            }
        }
    }

    private func userDeviationLine(in plot: CGRect) -> some View {
        let y = yPosition(for: userDeviation, in: plot)

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: plot.minX, y: y))
                path.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            .stroke(Color.uniexamIndigo.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))

            HStack(spacing: 3) {
                Text("▶︎")
                    .font(.caption2.weight(.bold))
                Text(String(format: "%.1f", userDeviation))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.uniexamIndigo)
            .position(x: plot.minX - 20, y: y)
        }
    }

    private func schoolLevelBands(in plot: CGRect) -> some View {
        let safeBottom = userDeviation - 7.5
        let safeTop = userDeviation - 2.5
        let matchBottom = userDeviation - 2.5
        let matchTop = userDeviation + 2.5
        let challengeBottom = userDeviation + 2.5
        let challengeTop = userDeviation + 7.5

        return ZStack(alignment: .topLeading) {
            band(from: safeBottom, to: safeTop, color: .schoolAmber, label: "安全校", in: plot)
            band(from: matchBottom, to: matchTop, color: .schoolMint, label: "相応校", in: plot)
            band(from: challengeBottom, to: challengeTop, color: .schoolCoral, label: "チャレンジ校", in: plot)
        }
    }

    @ViewBuilder
    private func band(from lower: Double, to upper: Double, color: Color, label: String, in plot: CGRect) -> some View {
        let range = visibleDeviationRange
        let clampedLower = min(max(lower, range.lowerBound), range.upperBound)
        let clampedUpper = min(max(upper, range.lowerBound), range.upperBound)

        if clampedUpper > clampedLower {
            let yTop = yPosition(for: clampedUpper, in: plot)
            let yBottom = yPosition(for: clampedLower, in: plot)
            Rectangle()
                .fill(color.opacity(0.22))
                .frame(width: plot.width, height: max(yBottom - yTop, 0))
                .position(x: plot.midX, y: yTop + (yBottom - yTop) / 2)

            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color.opacity(0.9))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.white.opacity(0.72), in: Capsule())
                .position(x: plot.maxX - 45, y: yTop + 16)
        }
    }

    private func yPosition(for deviation: Double, in plot: CGRect) -> CGFloat {
        let range = visibleDeviationRange
        let clampedDeviation = min(max(deviation, range.lowerBound), range.upperBound)
        return plot.maxY - plot.height * CGFloat((clampedDeviation - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private func grid(in plot: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: plot.minX, y: plot.minY))
                path.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                path.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            }
            .stroke(Color.primaryText.opacity(0.7), lineWidth: 1)

            ForEach(yAxisTicks, id: \.self) { value in
                let y = yPosition(for: value, in: plot)
                Path { path in
                    path.move(to: CGPoint(x: plot.minX, y: y))
                    path.addLine(to: CGPoint(x: plot.maxX, y: y))
                }
                .stroke(Color.secondaryText.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                Text(axisLabel(for: value))
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .position(x: plot.minX - 18, y: y)
            }

            ForEach([1, 5, 10, 15, 20, 25, 28], id: \.self) { day in
                let x = plot.minX + plot.width * CGFloat(Double(day - 1) / 27.0)
                Path { path in
                    path.move(to: CGPoint(x: x, y: plot.minY))
                    path.addLine(to: CGPoint(x: x, y: plot.maxY))
                }
                .stroke(Color.secondaryText.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                Text("2/\(day)")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .position(x: x, y: plot.maxY + 18)
            }

            Text("偏差値")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primaryText)
                .position(x: plot.minX + 6, y: plot.minY - 12)
        }
    }

    private var yAxisTicks: [Double] {
        let range = visibleDeviationRange
        let step = yZoomScale > 2.0 ? 2.5 : 5.0
        let first = ceil(range.lowerBound / step) * step
        var values: [Double] = []
        var value = first
        while value <= range.upperBound + 0.001 {
            values.append(value)
            value += step
        }
        return values
    }

    private func axisLabel(for value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct InsightRow: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.uniexamIndigo)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(detail.isEmpty ? "入試日程を登録すると表示されます" : detail)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
    }
}

struct FilterChip: View {
    var title: String
    var color: Color = .uniexamIndigo
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SchoolMonogram: View {
    var school: ExamSchool

    var body: some View {
        Text(String(school.name.prefix(1)))
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(school.color.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension ExamSchool {
    static func blank(nextColor: SchoolColor = .blue) -> ExamSchool {
        ExamSchool(
            name: "",
            faculty: "",
            method: "",
            deviation: 60,
            color: nextColor,
            examDate: nil,
            applicationStart: nil,
            applicationEnd: nil,
            paymentDeadline: nil,
            requiredDocuments: "",
            resultDate: nil,
            admissionFeeDeadline: nil,
            tuitionDeadline: nil,
            guidelineURL: "",
            passnaviURL: "",
            applicationURL: "",
            subjects: [],
            minimumPassingScore: "",
            acceptanceRatio: "",
            capacity: "",
            memo: ""
        )
    }

    static var samples: [ExamSchool] {
        [
            ExamSchool(
                name: "青葉大学",
                faculty: "経済学部",
                method: "一般A",
                deviation: 62,
                color: .blue,
                examDate: .from(year: 2027, month: 2, day: 10),
                applicationStart: .from(year: 2027, month: 1, day: 5),
                applicationEnd: .from(year: 2027, month: 1, day: 18),
                paymentDeadline: .from(year: 2027, month: 1, day: 20),
                requiredDocuments: "調査書、志望理由書、写真",
                resultDate: .from(year: 2027, month: 2, day: 18),
                admissionFeeDeadline: .from(year: 2027, month: 2, day: 25),
                tuitionDeadline: .from(year: 2027, month: 3, day: 8),
                guidelineURL: "https://www.aoba-u.ac.jp/nyushi/",
                passnaviURL: "https://passnavi.example/aoba",
                applicationURL: "",
                subjects: [
                    SubjectScore(subject: "英語", score: "200"),
                    SubjectScore(subject: "国語", score: "150"),
                    SubjectScore(subject: "数学", score: "150")
                ],
                minimumPassingScore: "378/500",
                acceptanceRatio: "2.6倍",
                capacity: "80名",
                memo: "英語の配点が高いので直前に重点確認"
            ),
            ExamSchool(
                name: "桜丘大学",
                faculty: "法学部",
                method: "共テ利用",
                deviation: 58,
                color: .coral,
                examDate: .from(year: 2027, month: 2, day: 6),
                applicationStart: .from(year: 2027, month: 1, day: 4),
                applicationEnd: .from(year: 2027, month: 1, day: 16),
                paymentDeadline: .from(year: 2027, month: 1, day: 17),
                requiredDocuments: "調査書、共通テスト成績請求票",
                resultDate: .from(year: 2027, month: 2, day: 14),
                admissionFeeDeadline: .from(year: 2027, month: 2, day: 21),
                tuitionDeadline: nil,
                guidelineURL: "",
                passnaviURL: "https://passnavi.example/sakuraoka",
                applicationURL: "https://entry.example/sakuraoka",
                subjects: [
                    SubjectScore(subject: "英語", score: "100"),
                    SubjectScore(subject: "国語", score: "100"),
                    SubjectScore(subject: "地歴公民", score: "100")
                ],
                minimumPassingScore: "",
                acceptanceRatio: "3.1倍",
                capacity: "45名",
                memo: ""
            ),
            ExamSchool(
                name: "東都大学",
                faculty: "文学部",
                method: "一般B",
                deviation: 65,
                color: .teal,
                examDate: .from(year: 2027, month: 2, day: 14),
                applicationStart: .from(year: 2027, month: 1, day: 8),
                applicationEnd: .from(year: 2027, month: 1, day: 25),
                paymentDeadline: .from(year: 2027, month: 1, day: 26),
                requiredDocuments: "",
                resultDate: .from(year: 2027, month: 2, day: 24),
                admissionFeeDeadline: .from(year: 2027, month: 2, day: 28),
                tuitionDeadline: .from(year: 2027, month: 3, day: 10),
                guidelineURL: "https://www.toto-u.ac.jp/admission/",
                passnaviURL: "",
                applicationURL: "",
                subjects: [
                    SubjectScore(subject: "英語", score: "200"),
                    SubjectScore(subject: "国語", score: "200"),
                    SubjectScore(subject: "小論文", score: "100")
                ],
                minimumPassingScore: "421/500",
                acceptanceRatio: "2.1倍",
                capacity: "60名",
                memo: "合格発表後の手続き締切が短い"
            )
        ]
    }
}

enum SchoolPersistence {
    private static let key = "uniexam.schools.v1"

    static func load() -> [ExamSchool] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return ExamSchool.samples
        }

        do {
            return try JSONDecoder().decode([ExamSchool].self, from: data)
        } catch {
            return ExamSchool.samples
        }
    }

    static func save(_ schools: [ExamSchool]) {
        guard let data = try? JSONEncoder().encode(schools) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum UserProfilePersistence {
    private static let deviationKey = "uniexam.userDeviation.v1"

    static func loadDeviation() -> Double {
        let storedValue = UserDefaults.standard.double(forKey: deviationKey)
        return storedValue == 0 ? 60 : storedValue
    }

    static func saveDeviation(_ deviation: Double) {
        UserDefaults.standard.set(deviation, forKey: deviationKey)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let deepNavy = Color(red: 0.12, green: 0.23, blue: 0.37)
    static let uniexamIndigo = Color(red: 0.28, green: 0.34, blue: 0.78)
    static let clearBlue = Color(red: 0.44, green: 0.65, blue: 0.91)
    static let appBackground = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let primaryText = Color(red: 0.19, green: 0.22, blue: 0.28)
    static let secondaryText = Color(red: 0.48, green: 0.52, blue: 0.58)
    static let schoolBlue = Color(hex: 0x6B8FF3)
    static let schoolDeepBlue = Color(hex: 0x4E7CE2)
    static let schoolRosePink = Color(hex: 0xF28AAE)
    static let schoolBrightRed = Color(hex: 0xFF6B6B)
    static let schoolPurple = Color(hex: 0xA78BFA)
    static let schoolViolet = Color(hex: 0xB79AF9)
    static let schoolMint = Color(hex: 0x4DCCA1)
    static let schoolTeal = Color(hex: 0x40C4C9)
    static let schoolLimeGreen = Color(hex: 0xB7D957)
    static let schoolAmber = Color(hex: 0xF6C453)
    static let schoolOrange = Color(hex: 0xFFB266)
    static let schoolCoral = Color(hex: 0xFF8F8F)
    static let schoolSkyBlue = Color(hex: 0x7BC0F8)
    static let schoolTurquoise = Color(hex: 0x5ED6E0)
    static let schoolSlate = Color(hex: 0xA6B2C7)
}

extension Date {
    static let demoToday = Date.from(year: 2027, month: 1, day: 10)

    static func from(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    static func applicationPeriodText(start: Date?, end: Date?) -> String {
        switch (start, end) {
        case let (start?, end?):
            "\(start.formatted(.shortMonthDay))〜\(end.formatted(.shortMonthDay))"
        case let (start?, nil):
            "\(start.formatted(.shortMonthDay))〜未設定"
        case let (nil, end?):
            "未設定〜\(end.formatted(.shortMonthDay))"
        default:
            ""
        }
    }

    static func applicationPeriodDaysText(start: Date?, end: Date?) -> String? {
        guard let start, let end else { return nil }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard let days = calendar.dateComponents([.day], from: startDay, to: endDay).day else { return nil }
        return "\(abs(days) + 1)日間"
    }
}

extension FormatStyle where Self == Date.FormatStyle {
    static var examDate: Date.FormatStyle {
        Date.FormatStyle()
            .year(.defaultDigits)
            .month(.defaultDigits)
            .day(.defaultDigits)
            .weekday(.abbreviated)
            .locale(Locale(identifier: "ja_JP"))
    }

    static var monthDayWeekday: Date.FormatStyle {
        Date.FormatStyle()
            .month(.defaultDigits)
            .day(.defaultDigits)
            .weekday(.abbreviated)
            .locale(Locale(identifier: "ja_JP"))
    }

    static var shortMonthDay: Date.FormatStyle {
        Date.FormatStyle()
            .month(.defaultDigits)
            .day(.defaultDigits)
            .locale(Locale(identifier: "ja_JP"))
    }

    static var yearMonth: Date.FormatStyle {
        Date.FormatStyle()
            .year(.defaultDigits)
            .month(.wide)
            .locale(Locale(identifier: "ja_JP"))
    }
}

#Preview {
    ContentView()
}
