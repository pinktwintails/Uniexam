//
//  ContentView.swift
//  Uniexam
//
//  Created by 岩崎未来 on 2026/07/23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var universities: [UniversityChoice]
    @State private var userDeviation: Double

    init() {
        _universities = State(initialValue: UniversityPersistence.load())
        _userDeviation = State(initialValue: UserProfilePersistence.loadDeviation())
    }

    private var schools: [ExamSchool] {
        universities.flatMap(\.joinedSchools)
    }

    var body: some View {
        TabView {
            UniversityListView(universities: $universities, listMode: .university)
                .tabItem {
                    Label("志望校", systemImage: "building.columns")
                }

            UniversityListView(universities: $universities, listMode: .examOption)
                .tabItem {
                    Label("入試方式", systemImage: "doc.text")
                }

            ExamCalendarView(universities: universities)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }

            StrategyMapView(schools: schools, userDeviation: $userDeviation)
                .tabItem {
                    Label("戦略", systemImage: "chart.xyaxis.line")
                }
        }
        .tint(.uniexamIndigo)
        .onChange(of: universities) { _, newValue in
            UniversityPersistence.save(newValue)
        }
        .onChange(of: userDeviation) { _, newValue in
            UserProfilePersistence.saveDeviation(newValue)
        }
    }
}

struct ExamSchool: Identifiable, Hashable, Codable {
    var id = UUID()
    var universityID: UUID?
    var name: String
    var nameKana: String
    var faculty: String
    var method: String
    var admissionCategory: ExamOptionCategory?
    var universityType: UniversityType
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
    var commonTestSubjects: [SubjectScore]
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

    var resolvedAdmissionCategory: ExamOptionCategory {
        admissionCategory ?? .inferred(from: method)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case universityID
        case name
        case nameKana
        case faculty
        case method
        case admissionCategory
        case universityType
        case deviation
        case color
        case examDate
        case applicationStart
        case applicationEnd
        case paymentDeadline
        case requiredDocuments
        case resultDate
        case admissionFeeDeadline
        case tuitionDeadline
        case guidelineURL
        case passnaviURL
        case applicationURL
        case subjects
        case commonTestSubjects
        case minimumPassingScore
        case acceptanceRatio
        case capacity
        case memo
    }

    init(
        id: UUID = UUID(),
        universityID: UUID? = nil,
        name: String,
        nameKana: String = "",
        faculty: String,
        method: String,
        admissionCategory: ExamOptionCategory? = nil,
        universityType: UniversityType = .privateSchool,
        deviation: Double,
        color: SchoolColor,
        examDate: Date?,
        applicationStart: Date?,
        applicationEnd: Date?,
        paymentDeadline: Date?,
        requiredDocuments: String,
        resultDate: Date?,
        admissionFeeDeadline: Date?,
        tuitionDeadline: Date?,
        guidelineURL: String,
        passnaviURL: String,
        applicationURL: String,
        subjects: [SubjectScore],
        commonTestSubjects: [SubjectScore] = [],
        minimumPassingScore: String,
        acceptanceRatio: String,
        capacity: String,
        memo: String
    ) {
        self.id = id
        self.universityID = universityID
        self.name = name
        self.nameKana = nameKana
        self.faculty = faculty
        self.method = method
        self.admissionCategory = admissionCategory
        self.universityType = universityType
        self.deviation = deviation
        self.color = color
        self.examDate = examDate
        self.applicationStart = applicationStart
        self.applicationEnd = applicationEnd
        self.paymentDeadline = paymentDeadline
        self.requiredDocuments = requiredDocuments
        self.resultDate = resultDate
        self.admissionFeeDeadline = admissionFeeDeadline
        self.tuitionDeadline = tuitionDeadline
        self.guidelineURL = guidelineURL
        self.passnaviURL = passnaviURL
        self.applicationURL = applicationURL
        self.subjects = subjects
        self.commonTestSubjects = commonTestSubjects
        self.minimumPassingScore = minimumPassingScore
        self.acceptanceRatio = acceptanceRatio
        self.capacity = capacity
        self.memo = memo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        universityID = try container.decodeIfPresent(UUID.self, forKey: .universityID)
        name = try container.decode(String.self, forKey: .name)
        nameKana = try container.decodeIfPresent(String.self, forKey: .nameKana) ?? ""
        faculty = try container.decode(String.self, forKey: .faculty)
        method = try container.decode(String.self, forKey: .method)
        admissionCategory = try container.decodeIfPresent(ExamOptionCategory.self, forKey: .admissionCategory)
        universityType = try container.decodeIfPresent(UniversityType.self, forKey: .universityType) ?? .privateSchool
        deviation = try container.decode(Double.self, forKey: .deviation)
        color = try container.decode(SchoolColor.self, forKey: .color)
        examDate = try container.decodeIfPresent(Date.self, forKey: .examDate)
        applicationStart = try container.decodeIfPresent(Date.self, forKey: .applicationStart)
        applicationEnd = try container.decodeIfPresent(Date.self, forKey: .applicationEnd)
        paymentDeadline = try container.decodeIfPresent(Date.self, forKey: .paymentDeadline)
        requiredDocuments = try container.decode(String.self, forKey: .requiredDocuments)
        resultDate = try container.decodeIfPresent(Date.self, forKey: .resultDate)
        admissionFeeDeadline = try container.decodeIfPresent(Date.self, forKey: .admissionFeeDeadline)
        tuitionDeadline = try container.decodeIfPresent(Date.self, forKey: .tuitionDeadline)
        guidelineURL = try container.decode(String.self, forKey: .guidelineURL)
        passnaviURL = try container.decode(String.self, forKey: .passnaviURL)
        applicationURL = try container.decode(String.self, forKey: .applicationURL)
        subjects = try container.decode([SubjectScore].self, forKey: .subjects)
        commonTestSubjects = try container.decodeIfPresent([SubjectScore].self, forKey: .commonTestSubjects) ?? []
        minimumPassingScore = try container.decode(String.self, forKey: .minimumPassingScore)
        acceptanceRatio = try container.decode(String.self, forKey: .acceptanceRatio)
        capacity = try container.decode(String.self, forKey: .capacity)
        memo = try container.decode(String.self, forKey: .memo)
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
            items.append(DetailItem(title: "個別試験 科目・配点", value: subjects.map(\.displayText).joined(separator: " / "), systemImage: "book"))
        }
        if !commonTestSubjects.isEmpty {
            items.append(DetailItem(title: "共通テスト 科目・配点", value: commonTestSubjects.map(\.displayText).joined(separator: " / "), systemImage: "checklist"))
        }
        appendText("合格者最低点", minimumPassingScore, "target", &items)
        appendText("倍率", acceptanceRatio, "chart.bar", &items)
        appendText("募集人数", capacity, "person.3", &items)
        appendText("メモ", memo, "note.text", &items)
        return items
    }

    var events: [ExamEvent] {
        [
            makeEvent(kind: .applicationStart, date: applicationStart, title: "出願開始"),
            makeEvent(kind: .applicationEnd, date: applicationEnd, title: "出願締切"),
            makeEvent(kind: .paymentDeadline, date: paymentDeadline, title: "入金締切"),
            makeEvent(kind: .exam, date: examDate, title: "入試日程"),
            makeEvent(kind: .result, date: resultDate, title: "合格発表"),
            makeEvent(kind: .admissionFee, date: admissionFeeDeadline, title: "入学金締切"),
            makeEvent(kind: .tuition, date: tuitionDeadline, title: "授業料締切")
        ].compactMap { $0.date == nil ? nil : $0 }
    }

    private func makeEvent(kind: EventKind, date: Date?, title: String) -> ExamEvent {
        ExamEvent(
            universityID: universityID ?? id,
            examOptionID: id,
            schoolName: name,
            faculty: faculty,
            optionName: method,
            schoolColor: color,
            kind: kind,
            date: date,
            title: title
        )
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

enum UniversityType: String, CaseIterable, Identifiable, Codable {
    case nationalPublic
    case privateSchool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nationalPublic: "国公立"
        case .privateSchool: "私立"
        }
    }

    var systemImage: String {
        switch self {
        case .nationalPublic: "building.2.fill"
        case .privateSchool: "building.columns.fill"
        }
    }
}

struct ExamEvent: Identifiable, Hashable {
    var id = UUID()
    var universityID: UUID
    var examOptionID: UUID
    var schoolName: String
    var faculty: String
    var optionName: String
    var schoolColor: SchoolColor
    var kind: EventKind
    var date: Date?
    var title: String

    var schoolID: UUID { examOptionID }

    var compactCalendarTitle: String {
        calendarTitle(includesUniversityName: true)
    }

    func calendarTitle(includesUniversityName: Bool) -> String {
        let university = schoolName.replacingOccurrences(of: "大学", with: "")
        let option = optionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !includesUniversityName {
            return kind.shortTitle
        }
        return option.isEmpty ? "\(kind.shortTitle) \(university)" : "\(kind.shortTitle) \(university)・\(option)"
    }
}

struct CalendarApplicationRange: Identifiable, Hashable {
    var id = UUID()
    var universityID: UUID
    var examOptionID: UUID
    var schoolName: String
    var faculty: String
    var optionName: String
    var schoolColor: SchoolColor
    var startDate: Date
    var endDate: Date
    var lane: Int = 0

    var schoolID: UUID { examOptionID }

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

    var calendarPriority: Int {
        switch self {
        case .exam: 0
        case .applicationEnd: 1
        case .paymentDeadline, .admissionFee, .tuition: 2
        case .result: 3
        case .applicationStart, .all: 4
        }
    }
}

enum SchoolColor: CaseIterable, Identifiable, Codable, Hashable {
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
    case custom(name: String, hex: String)

    static let allCases: [SchoolColor] = [
        .blue,
        .rosePink,
        .brightRed,
        .purple,
        .mint,
        .teal,
        .limeGreen,
        .amber,
        .skyBlue,
        .slate
    ]

    var id: String { storageValue }

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
        case let .custom(_, hex): Color(hexString: hex)
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
        case let .custom(name, _): name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "カスタムカラー" : name
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
        case let .custom(_, hex): Self.normalizedHex(hex)
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if value.hasPrefix("custom|") {
            let components = value.split(separator: "|", omittingEmptySubsequences: false)
            if components.count == 3,
               let nameData = Data(base64Encoded: String(components[1])),
               let name = String(data: nameData, encoding: .utf8) {
                self = .custom(name: name, hex: String(components[2]))
                return
            }
        }
        if value.hasPrefix("custom:") {
            self = .custom(name: "カスタムカラー", hex: String(value.dropFirst("custom:".count)))
            return
        }

        self = switch value {
        case "blue": .blue
        case "deepBlue": .deepBlue
        case "rosePink": .rosePink
        case "brightRed": .brightRed
        case "purple": .purple
        case "violet": .violet
        case "mint": .mint
        case "teal": .teal
        case "limeGreen": .limeGreen
        case "amber": .amber
        case "orange": .orange
        case "coral": .coral
        case "skyBlue": .skyBlue
        case "turquoise": .turquoise
        case "slate": .slate
        default: .blue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }

    private var storageValue: String {
        switch self {
        case .blue: "blue"
        case .deepBlue: "deepBlue"
        case .rosePink: "rosePink"
        case .brightRed: "brightRed"
        case .purple: "purple"
        case .violet: "violet"
        case .mint: "mint"
        case .teal: "teal"
        case .limeGreen: "limeGreen"
        case .amber: "amber"
        case .orange: "orange"
        case .coral: "coral"
        case .skyBlue: "skyBlue"
        case .turquoise: "turquoise"
        case .slate: "slate"
        case let .custom(name, hex):
            "custom|\(Data(name.utf8).base64EncodedString())|\(Self.normalizedHex(hex))"
        }
    }

    private static func normalizedHex(_ value: String) -> String {
        let digits = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        return "#\(String(digits.prefix(6)))"
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

enum SchoolSortOption: String, CaseIterable, Identifiable {
    case alphabetical
    case deviation
    case examDate
    case nearestEvent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical: "五十音順"
        case .deviation: "偏差値順"
        case .examDate: "試験日程順"
        case .nearestEvent: "直近の予定順"
        }
    }

    var systemImage: String {
        switch self {
        case .alphabetical: "textformat.abc"
        case .deviation: "chart.line.uptrend.xyaxis"
        case .examDate: "calendar"
        case .nearestEvent: "clock.badge"
        }
    }
}

struct SchoolListView: View {
    @Binding var schools: [ExamSchool]
    @State private var showingAddSheet = false
    @AppStorage("schoolListSortOption") private var sortOption = SchoolSortOption.alphabetical

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(title: "志望校", trailingSystemImage: "plus", trailingAction: {
                    showingAddSheet = true
                })

                HStack(spacing: 12) {
                    Text("\(schools.count)校")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)

                    Spacer()

                    Menu {
                        Picker("並び替え", selection: $sortOption) {
                            ForEach(SchoolSortOption.allCases) { option in
                                Label(option.title, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Label(sortOption.title, systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.uniexamIndigo)
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(Color.uniexamIndigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .accessibilityLabel("志望校を並び替え")
                    .accessibilityValue(sortOption.title)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.white)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedSchools) { school in
                            NavigationLink {
                                SchoolDetailView(school: binding(for: school))
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

    private var sortedSchools: [ExamSchool] {
        schools.sorted { lhs, rhs in
            switch sortOption {
            case .alphabetical:
                return alphabeticallyPrecedes(lhs, rhs)
            case .deviation:
                if lhs.deviation != rhs.deviation {
                    return lhs.deviation > rhs.deviation
                }
                return alphabeticallyPrecedes(lhs, rhs)
            case .examDate:
                return datePrecedes(lhs.examDate, rhs.examDate, lhs: lhs, rhs: rhs)
            case .nearestEvent:
                return datePrecedes(nextEventDate(for: lhs), nextEventDate(for: rhs), lhs: lhs, rhs: rhs)
            }
        }
    }

    private func alphabeticallyPrecedes(_ lhs: ExamSchool, _ rhs: ExamSchool) -> Bool {
        let lhsSortName = lhs.nameKana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? lhs.name : lhs.nameKana
        let rhsSortName = rhs.nameKana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rhs.name : rhs.nameKana
        let nameComparison = lhsSortName.compare(
            rhsSortName,
            options: [.caseInsensitive, .widthInsensitive],
            range: nil,
            locale: Locale(identifier: "ja_JP")
        )
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        let detailComparison = "\(lhs.faculty)\(lhs.method)".localizedStandardCompare("\(rhs.faculty)\(rhs.method)")
        if detailComparison != .orderedSame {
            return detailComparison == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func datePrecedes(_ lhsDate: Date?, _ rhsDate: Date?, lhs: ExamSchool, rhs: ExamSchool) -> Bool {
        switch (lhsDate, rhsDate) {
        case let (lhsDate?, rhsDate?):
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return alphabeticallyPrecedes(lhs, rhs)
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return alphabeticallyPrecedes(lhs, rhs)
        }
    }

    private func nextEventDate(for school: ExamSchool) -> Date? {
        school.events
            .compactMap(\.date)
            .filter { $0 >= .demoToday }
            .min()
    }

    private func binding(for school: ExamSchool) -> Binding<ExamSchool> {
        Binding(
            get: { schools.first(where: { $0.id == school.id }) ?? school },
            set: { updatedSchool in
                guard let index = schools.firstIndex(where: { $0.id == school.id }) else { return }
                schools[index] = updatedSchool
            }
        )
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

                    Text("\(school.faculty.isEmpty ? "学部未入力" : school.faculty)  |  \(school.universityType.displayName)  |  \(school.method)  |  偏差値 \(school.deviationText)")
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
    var fixedUniversity: UniversityChoice? = nil
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
            EditSchoolView(mode: .edit, school: school, fixedUniversity: fixedUniversity) { updatedSchool in
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
                    title: "個別試験 科目・配点",
                    value: school.subjects.map(\.displayText).joined(separator: " / "),
                    systemImage: "book.closed.fill"
                )
            )
        }
        if !school.commonTestSubjects.isEmpty {
            items.append(
                DetailItem(
                    title: "共通テスト 科目・配点",
                    value: school.commonTestSubjects.map(\.displayText).joined(separator: " / "),
                    systemImage: "checklist"
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
                    HStack(spacing: 8) {
                        Label(school.universityType.displayName, systemImage: school.universityType.systemImage)
                        Label(school.method, systemImage: "list.clipboard")
                    }
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
        case nameKana
        case method
        case faculty
        case deviation
    }

    @Environment(\.dismiss) private var dismiss
    var mode: Mode
    @State var school: ExamSchool
    var fixedUniversity: UniversityChoice? = nil
    @State private var expandedSections: Set<EditorSection> = []
    @FocusState private var focusedField: FocusedField?
    var onSave: (ExamSchool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorProgressHeader(
                        completedRequiredCount: completedRequiredCount,
                        requiredFieldCount: requiredFieldCount,
                        optionalFieldCount: optionalFieldCount,
                        tint: school.color.color
                    )
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                }

                Section {
                    if let fixedUniversity {
                        HStack(spacing: 12) {
                            Text(String(fixedUniversity.name.prefix(1)))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(fixedUniversity.color.color, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(fixedUniversity.name)
                                    .font(.headline)
                                Text("\(fixedUniversity.universityType.displayName)・大学情報は共通で管理")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else {
                        EditorTextField(
                            title: "学校名",
                            placeholder: "例：青葉大学",
                            systemImage: "building.columns.fill",
                            text: $school.name,
                            isRequired: true
                        )
                        .focused($focusedField, equals: .name)

                        EditorTextField(
                            title: "学校名（ふりがな）",
                            placeholder: "例：あおばだいがく",
                            systemImage: "textformat",
                            text: $school.nameKana
                        )
                        .focused($focusedField, equals: .nameKana)

                        VStack(alignment: .leading, spacing: 10) {
                            EditorFieldLabel(title: "大学種別", systemImage: "building.2.crop.circle.fill", isRequired: true)
                            Picker("大学種別", selection: $school.universityType) {
                                ForEach(UniversityType.allCases) { type in
                                    Label(type.displayName, systemImage: type.systemImage)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)
                    }

                    EditorTextField(
                        title: "入試方式",
                        placeholder: "例：一般A・共通テスト利用",
                        systemImage: "list.clipboard.fill",
                        text: $school.method,
                        isRequired: true
                    )
                    .focused($focusedField, equals: .method)

                    VStack(alignment: .leading, spacing: 10) {
                        EditorFieldLabel(title: "方式区分", systemImage: "rectangle.3.group")
                        Picker("方式区分", selection: admissionCategoryBinding) {
                            ForEach(ExamOptionCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            EditorFieldLabel(title: "偏差値", systemImage: "chart.line.uptrend.xyaxis", isRequired: true)
                            Spacer()
                            TextField("60.0", value: deviationBinding, format: .number.precision(.fractionLength(1)))
                                .font(.headline.weight(.bold))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .deviation)
                                .foregroundStyle(Color.deepNavy)
                                .frame(width: 64)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(school.color.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                        }
                        Slider(value: deviationBinding, in: 30...80, step: 0.5)
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

                    if fixedUniversity == nil {
                        VStack(alignment: .leading, spacing: 12) {
                            EditorFieldLabel(title: "大学カラー", systemImage: "paintpalette.fill", isRequired: true)
                            SchoolColorPicker(selection: $school.color)
                        }
                    }
                } header: {
                    Text(fixedUniversity == nil ? "必須項目" : "入試方式の基本情報")
                } footer: {
                    if completedRequiredCount < requiredFieldCount {
                        Label(fixedUniversity == nil ? "学校名・大学種別・入試方式・学部学科を入力すると保存できます" : "入試方式・学部学科を入力すると保存できます", systemImage: "info.circle")
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
                    if fixedUniversity == nil {
                        EditorTextField(title: "パスナビURL", placeholder: "https://", systemImage: "link", text: $school.passnaviURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
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
                    SubjectEditor(
                        title: "個別試験の科目ごとの配点",
                        systemImage: "book.closed.fill",
                        addPlaceholder: "個別試験の科目を追加",
                        subjects: $school.subjects
                    )
                    SubjectEditor(
                        title: "共通テストの科目ごとの配点",
                        systemImage: "checklist",
                        addPlaceholder: "共通テストの科目を追加",
                        subjects: $school.commonTestSubjects
                    )
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
            .navigationTitle(fixedUniversity == nil ? (mode == .add ? "志望校を追加" : "志望校を編集") : (mode == .add ? "入試方式を追加" : "入試方式を編集"))
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
                    focusedField = fixedUniversity == nil ? .name : .method
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

    private var deviationBinding: Binding<Double> {
        Binding(
            get: { school.deviation },
            set: { newValue in
                school.deviation = min(80, max(30, (newValue * 2).rounded() / 2))
            }
        )
    }

    private var admissionCategoryBinding: Binding<ExamOptionCategory> {
        Binding(
            get: { school.resolvedAdmissionCategory },
            set: { school.admissionCategory = $0 }
        )
    }

    private var completedRequiredCount: Int {
        if fixedUniversity != nil {
            return [
                !school.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !school.faculty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                true
            ].filter { $0 }.count
        }
        return [
            !school.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            true,
            !school.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !school.faculty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            true,
            true
        ].filter { $0 }.count
    }

    private var requiredFieldCount: Int {
        fixedUniversity == nil ? 6 : 3
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
        (school.subjects.isEmpty ? 0 : 1) + (school.commonTestSubjects.isEmpty ? 0 : 1) + nonEmptyCount([
            school.minimumPassingScore,
            school.acceptanceRatio,
            school.capacity
        ])
    }

    private var notesCount: Int {
        nonEmptyCount([school.memo])
    }

    private var optionalFieldCount: Int {
        nonEmptyCount([school.nameKana]) + scheduleCount + applicationInformationCount + examInformationCount + notesCount
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
    var title: String
    var systemImage: String
    var addPlaceholder: String
    @Binding var subjects: [SubjectScore]
    @State private var newSubject = ""
    @State private var newScore = ""

    var body: some View {
        EditorFieldLabel(title: title, systemImage: systemImage)

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
            TextField(addPlaceholder, text: $newSubject)
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
    var completedRequiredCount: Int
    var requiredFieldCount: Int = 6
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
    @State private var customColors = CustomSchoolColorPersistence.load()
    @State private var draftColor = Color.schoolBlue
    @State private var draftColorName = ""
    @State private var colorPendingDeletion: SchoolColor?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 5
    )

    private let customColumns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 3
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
                                .stroke(selection.isCustom ? Color.deepNavy : Color.white, lineWidth: 2)
                        }
                        .shadow(color: selection.color.opacity(0.35), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Text(selection.isCustom ? "保存したカスタム色" : "プリセットカラー")
                            .font(.caption)
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
            .accessibilityValue(selection.displayName)
            .accessibilityHint(isExpanded ? "閉じる" : "色を選ぶ")

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(SchoolColor.allCases) { color in
                            colorButton(color)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("カスタムカラー")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.primaryText)

                        TextField("色の名前", text: $draftColorName)
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 10)
                            .frame(height: 40)
                            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 6))

                        HStack(spacing: 10) {
                            ColorPicker("色を選ぶ", selection: $draftColor, supportsOpacity: false)
                                .font(.subheadline.weight(.semibold))

                            Button {
                                saveDraftColor()
                            } label: {
                                Label("保存", systemImage: "plus")
                                    .font(.subheadline.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.uniexamIndigo)
                            .disabled(draftColorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if !customColors.isEmpty {
                            LazyVGrid(columns: customColumns, spacing: 12) {
                                ForEach(customColors) { color in
                                    customColorButton(color)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .confirmationDialog(
            "保存したカスタム色を削除しますか？",
            isPresented: Binding(
                get: { colorPendingDeletion != nil },
                set: { if !$0 { colorPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                guard let colorPendingDeletion else { return }
                customColors.removeAll { $0 == colorPendingDeletion }
                CustomSchoolColorPersistence.save(customColors)
                if selection == colorPendingDeletion {
                    selection = .blue
                }
                self.colorPendingDeletion = nil
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すでに保存済みの他大学の色は変更されません。")
        }
    }

    private func colorButton(_ color: SchoolColor) -> some View {
        Button {
            select(color)
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
        .accessibilityAddTraits(selection == color ? .isSelected : [])
    }

    private func customColorButton(_ color: SchoolColor) -> some View {
        VStack(spacing: 6) {
            Button {
                select(color)
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
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .stroke(
                            selection == color ? Color.deepNavy : color.color.opacity(0.5),
                            lineWidth: selection == color ? 3 : 2
                        )
                        .padding(-4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(color.displayName)
            .accessibilityAddTraits(selection == color ? .isSelected : [])

            HStack(spacing: 2) {
                Text(color.displayName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Color.primaryText)

                Button(role: .destructive) {
                    colorPendingDeletion = color
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel("\(color.displayName)を削除")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func select(_ color: SchoolColor) {
        selection = color
        draftColor = color.color
        if color.isCustom {
            draftColorName = color.displayName
        }
    }

    private func saveDraftColor() {
        let name = draftColorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let hex = draftColor.rgbHexCode else { return }

        let customColor = SchoolColor.custom(name: name, hex: hex)
        if !customColors.contains(customColor) {
            customColors.append(customColor)
            CustomSchoolColorPersistence.save(customColors)
        }
        selection = customColor
        draftColorName = ""
    }
}

struct ExamCalendarView: View {
    var universities: [UniversityChoice]
    @State private var selectedDate = Date.from(year: 2027, month: 2, day: 6)
    @State private var displayedMonth = Date.from(year: 2027, month: 2, day: 1)
    @State private var selectedKind: EventKind = .all
    @State private var selectedUniversityID: UUID?
    @State private var selectedOptionID: UUID?
    @State private var showingFilters = false

    private let calendar = Calendar.current

    private var schools: [ExamSchool] {
        universities.flatMap(\.joinedSchools)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(
                    title: "カレンダー",
                    trailingSystemImage: "line.3.horizontal.decrease.circle",
                    trailingAction: { showingFilters = true }
                )

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
            .sheet(isPresented: $showingFilters) {
                CalendarFilterSheet(
                    universities: universities,
                    selectedKind: $selectedKind,
                    selectedUniversityID: $selectedUniversityID,
                    selectedOptionID: $selectedOptionID
                )
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "すべて", isSelected: selectedKind == .all && selectedUniversityID == nil && selectedOptionID == nil) {
                    selectedKind = .all
                    selectedUniversityID = nil
                    selectedOptionID = nil
                }

                FilterChip(title: "入試日程", isSelected: selectedKind == .exam) {
                    selectedKind = .exam
                }

                FilterChip(title: "締切のみ", isSelected: selectedKind == .applicationEnd) {
                    selectedKind = .applicationEnd
                }

                if let university = universities.first(where: { $0.id == selectedUniversityID }) {
                    FilterChip(title: university.name, color: university.color.color, isSelected: true) {
                        showingFilters = true
                    }
                }

                if let option = selectedOption {
                    FilterChip(title: option.title, isSelected: true) {
                        showingFilters = true
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
                let universityMatches = selectedUniversityID == nil || event.universityID == selectedUniversityID
                let optionMatches = selectedOptionID == nil || event.examOptionID == selectedOptionID
                return kindMatches && universityMatches && optionMatches
            }
    }

    private var visibleApplicationRanges: [CalendarApplicationRange] {
        guard selectedKind == .all || selectedKind == .applicationStart || selectedKind == .applicationEnd else {
            return []
        }

        let ranges = schools.compactMap { school -> CalendarApplicationRange? in
            guard selectedUniversityID == nil || selectedUniversityID == school.universityID else { return nil }
            guard selectedOptionID == nil || selectedOptionID == school.id else { return nil }
            guard let startDate = school.applicationStart, let endDate = school.applicationEnd else { return nil }
            return CalendarApplicationRange(
                universityID: school.universityID ?? school.id,
                examOptionID: school.id,
                schoolName: school.name,
                faculty: school.faculty,
                optionName: school.method,
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
            .sorted(by: eventPrecedes)
    }

    private var selectedOption: ExamOption? {
        universities
            .flatMap(\.examOptions)
            .first { $0.id == selectedOptionID }
    }

    private func eventPrecedes(_ lhs: ExamEvent, _ rhs: ExamEvent) -> Bool {
        let lhsPriority = lhs.kind.calendarPriority
        let rhsPriority = rhs.kind.calendarPriority
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        return lhs.schoolName.localizedStandardCompare(rhs.schoolName) == .orderedAscending
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
    var showsUniversityNameInEvents = true
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
                            applicationRanges: applicationRangesForDay(date),
                            showsUniversityNameInEvents: showsUniversityNameInEvents
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
        .sorted {
            if $0.kind.calendarPriority != $1.kind.calendarPriority {
                return $0.kind.calendarPriority < $1.kind.calendarPriority
            }
            return $0.schoolName.localizedStandardCompare($1.schoolName) == .orderedAscending
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
    var showsUniversityNameInEvents = true

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
                    Text(event.calendarTitle(includesUniversityName: showsUniversityNameInEvents))
                        .font(.system(size: 10.5, weight: .bold))
                        .lineLimit(showsUniversityNameInEvents ? 2 : 1)
                        .foregroundStyle(event.schoolColor.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(event.schoolColor.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                let hiddenCount = max(applicationRanges.count - visibleRangeLaneCount, 0) + max(events.count - 2, 0)
                if hiddenCount > 0 {
                    Text("ほか\(hiddenCount)件")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 0)

                ForEach(0..<visibleRangeLaneCount, id: \.self) { lane in
                    if let range = applicationRanges.first(where: { $0.lane == lane }) {
                        ApplicationRangeRibbon(range: range, date: date)
                    } else {
                        Color.clear
                            .frame(height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(height: 112)
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
                        .font(.system(size: 8, weight: .bold))
                }

                Rectangle()
                    .frame(height: 2.5)

                if range.isEnd(date, calendar: calendar) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundStyle(range.schoolColor.color)

            if range.isStart(date, calendar: calendar) || range.isEnd(date, calendar: calendar) {
                Text(range.isStart(date, calendar: calendar) ? "出願" : "締切")
                    .font(.system(size: 9.5, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(range.schoolColor.color, in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, -2)
        .frame(height: 12)
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
                Text([event.faculty, event.optionName, event.title].filter { !$0.isEmpty }.joined(separator: "・"))
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

struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    var universities: [UniversityChoice]
    @Binding var selectedKind: EventKind
    @Binding var selectedUniversityID: UUID?
    @Binding var selectedOptionID: UUID?

    private var selectedUniversity: UniversityChoice? {
        universities.first { $0.id == selectedUniversityID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("予定種別") {
                    Picker("予定種別", selection: $selectedKind) {
                        ForEach(EventKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("大学") {
                    Button {
                        selectedUniversityID = nil
                        selectedOptionID = nil
                    } label: {
                        filterSelectionRow(title: "すべての大学", selected: selectedUniversityID == nil)
                    }
                    .buttonStyle(.plain)

                    ForEach(universities) { university in
                        Button {
                            selectedUniversityID = university.id
                            selectedOptionID = nil
                        } label: {
                            filterSelectionRow(
                                title: university.name,
                                color: university.color.color,
                                selected: selectedUniversityID == university.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let selectedUniversity {
                    Section("入試方式") {
                        Button { selectedOptionID = nil } label: {
                            filterSelectionRow(title: "すべての入試方式", selected: selectedOptionID == nil)
                        }
                        .buttonStyle(.plain)

                        ForEach(selectedUniversity.examOptions) { option in
                            Button { selectedOptionID = option.id } label: {
                                filterSelectionRow(
                                    title: option.title.isEmpty ? "名称未入力" : option.title,
                                    color: selectedUniversity.color.color,
                                    selected: selectedOptionID == option.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("カレンダーを絞り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func filterSelectionRow(title: String, color: Color? = nil, selected: Bool) -> some View {
        HStack {
            if let color {
                Circle().fill(color).frame(width: 10, height: 10)
            }
            Text(title).foregroundStyle(Color.primaryText)
            Spacer()
            if selected {
                Image(systemName: "checkmark").foregroundStyle(Color.uniexamIndigo)
            }
        }
        .contentShape(Rectangle())
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
            nameKana: "",
            faculty: "",
            method: "",
            universityType: .privateSchool,
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
            commonTestSubjects: [],
            minimumPassingScore: "",
            acceptanceRatio: "",
            capacity: "",
            memo: ""
        )
    }

    static var samples: [ExamSchool] {
        UniversityChoice.samples.flatMap(\.joinedSchools)
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

enum CustomSchoolColorPersistence {
    private static let key = "uniexam.customSchoolColors.v1"

    static func load() -> [SchoolColor] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let colors = try? JSONDecoder().decode([SchoolColor].self, from: data) else {
            return []
        }
        return colors.filter(\.isCustom)
    }

    static func save(_ colors: [SchoolColor]) {
        guard let data = try? JSONEncoder().encode(colors.filter(\.isCustom)) else { return }
        UserDefaults.standard.set(data, forKey: key)
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

    init(hexString: String) {
        let digits = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt32(digits, radix: 16) ?? 0x6B8FF3
        self.init(hex: value)
    }

    var rgbHexCode: String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
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
