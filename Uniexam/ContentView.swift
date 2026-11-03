//
//  ContentView.swift
//  Uniexam
//
//  Created by 岩崎未来 on 2026/07/23.
//

import Combine
import SwiftUI
import UIKit

private struct AppSidebarActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openAppSidebar: () -> Void {
        get { self[AppSidebarActionKey.self] }
        set { self[AppSidebarActionKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    private let cloudRefreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    @State private var universities: [UniversityChoice]
    @State private var mockExamResults: [MockExamResult]
    @State private var customCalendarEvents: [UserCalendarEvent]
    @State private var showingSidebar = false
    @State private var showingHiddenItems = false
    @State private var showingMockExamResults = false
    @State private var cloudSyncReady = false
    @State private var lastAppliedCloudPayload: Data?
    @State private var cloudSyncDebounceTask: Task<Void, Never>?

    init() {
        let loadedUniversities = UniversityPersistence.load()
        _universities = State(initialValue: loadedUniversities)
        _mockExamResults = State(initialValue: MockExamResultPersistence.load(universities: loadedUniversities))
        _customCalendarEvents = State(initialValue: UserCalendarEventPersistence.load())
    }

    private var schools: [ExamSchool] {
        universities
            .filter { !$0.isHidden }
            .flatMap { $0.joinedSchools.filter { !$0.isHidden } }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            TabView {
                UniversityListView(
                    universities: $universities,
                    customEvents: $customCalendarEvents,
                    listMode: .university
                )
                    .tabItem {
                        Label("志望校", systemImage: "building.columns")
                    }

                UniversityListView(
                    universities: $universities,
                    customEvents: $customCalendarEvents,
                    listMode: .examOption
                )
                    .tabItem {
                        Label("入試方式", systemImage: "doc.text")
                    }

                ExamCalendarView(universities: $universities, customEvents: $customCalendarEvents)
                    .tabItem {
                        Label("カレンダー", systemImage: "calendar")
                    }

                StrategyMapView(
                    schools: schools,
                    userDeviation: latestMockExamDeviation,
                    mockExamResults: mockExamResults
                )
                    .tabItem {
                        Label("戦略", systemImage: "chart.xyaxis.line")
                    }
            }
            .tint(.uniexamIndigo)
            .allowsHitTesting(!showingSidebar)

            if showingSidebar {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { closeSidebar() }
                    .transition(.opacity)

                AppSidebarView(
                    onClose: closeSidebar,
                    onShowHiddenItems: {
                        closeSidebar()
                        showingHiddenItems = true
                    },
                    onShowMockExamResults: {
                        closeSidebar()
                        showingMockExamResults = true
                    }
                )
                    .frame(width: 304)
                    .transition(.move(edge: .leading))
                    .zIndex(1)
            }
        }
        .environment(\.openAppSidebar) {
            withAnimation(.snappy(duration: 0.24)) {
                showingSidebar = true
            }
        }
        .animation(.snappy(duration: 0.24), value: showingSidebar)
        .sheet(isPresented: $showingHiddenItems) {
            HiddenItemsView(universities: $universities)
        }
        .sheet(isPresented: $showingMockExamResults) {
            MockExamResultsView(results: $mockExamResults, universities: universities)
        }
        .onChange(of: universities) { _, newValue in
            UniversityPersistence.save(newValue)
            syncCurrentDataIfReady()
        }
        .onChange(of: mockExamResults) { _, newValue in
            MockExamResultPersistence.save(newValue)
            syncCurrentDataIfReady()
        }
        .onChange(of: customCalendarEvents) { _, newValue in
            UserCalendarEventPersistence.save(newValue)
            syncCurrentDataIfReady()
        }
        .onAppear {
            bootstrapCloudSyncIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshCloudData()
            }
        }
        .onReceive(cloudRefreshTimer) { _ in
            if scenePhase == .active {
                refreshCloudData()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .uniexamCustomColorsDidChange
            )
        ) { _ in
            syncCurrentDataIfReady()
        }
    }

    private func closeSidebar() {
        withAnimation(.snappy(duration: 0.22)) {
            showingSidebar = false
        }
    }

    private var latestMockExamDeviation: Double? {
        mockExamResults.max { lhs, rhs in
            lhs.date < rhs.date
        }?.deviation
    }

    private func bootstrapCloudSyncIfNeeded() {
        guard !cloudSyncReady else { return }
        cloudSyncReady = true
        refreshCloudData()
    }

    private func applyCloudSnapshot(_ snapshot: UniexamCloudSnapshot) {
        lastAppliedCloudPayload = try? JSONEncoder().encode(snapshot)
        universities = snapshot.universities
        mockExamResults = snapshot.mockExamResults
        customCalendarEvents = snapshot.calendarEvents
        CustomSchoolColorPersistence.save(snapshot.customColors)
    }

    private func syncCurrentDataIfReady() {
        guard cloudSyncReady else { return }

        let snapshot = currentCloudSnapshot()
        if let payload = try? JSONEncoder().encode(snapshot),
           payload == lastAppliedCloudPayload {
            return
        }

        cloudSyncDebounceTask?.cancel()
        cloudSyncDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            if let mergedSnapshot = await UniexamCloudSync.shared.synchronize(snapshot) {
                applyCloudSnapshot(mergedSnapshot)
            }
        }
    }

    private func refreshCloudData() {
        guard cloudSyncReady else { return }
        let snapshot = currentCloudSnapshot()
        Task {
            if let mergedSnapshot = await UniexamCloudSync.shared.synchronize(snapshot) {
                applyCloudSnapshot(mergedSnapshot)
            }
        }
    }

    private func currentCloudSnapshot() -> UniexamCloudSnapshot {
        UniexamCloudSnapshot.local(
            universities: universities,
            mockExamResults: mockExamResults,
            calendarEvents: customCalendarEvents,
            customColors: CustomSchoolColorPersistence.load()
        )
    }
}

struct AppSidebarView: View {
    var onClose: () -> Void
    var onShowHiddenItems: () -> Void
    var onShowMockExamResults: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.uniexamIndigo, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Uniexam")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primaryText)
                    Text("受験スケジュール")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel("サイドバーを閉じる")
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)

            Divider()

            Label("メニュー", systemImage: "square.grid.2x2")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
                .padding(.horizontal, 20)
                .padding(.top, 22)

            VStack(spacing: 4) {
                Button(action: onShowHiddenItems) {
                    sidebarRow(title: "非表示の項目を見る", systemImage: "archivebox")
                }
                .buttonStyle(.plain)
                Button(action: onShowMockExamResults) {
                    sidebarRow(title: "模試結果登録", systemImage: "chart.bar.doc.horizontal")
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("模試結果登録")
                .accessibilityAddTraits(.isButton)

                if let contactURL = URL(string: "https://app.notion.com/p/b7bfd12bf238821c8c210131da435e65?pvs=106") {
                    Link(destination: contactURL) {
                        sidebarRow(title: "問い合わせ", systemImage: "envelope")
                    }
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background {
            Color.white.ignoresSafeArea()
        }
        .shadow(color: .black.opacity(0.16), radius: 18, x: 8)
    }

    private func sidebarRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.uniexamIndigo)
                .frame(width: 28)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .contentShape(Rectangle())
    }
}

struct ExamSchool: Identifiable, Hashable, Codable {
    var id = UUID()
    var isHidden = false
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
    var documentMailingDeadline: Date?
    var documentMailingDeadlineRule: DocumentMailingDeadlineRule?
    var requiredDocuments: String
    var requiredDocumentItems: [ExamRequiredDocument]
    var resultDate: Date?
    var admissionFeeDeadline: Date?
    var tuitionDeadline: Date?
    var guidelineURL: String
    var passnaviURL: String
    var applicationURL: String
    var subjects: [SubjectScore]
    var commonTestSubjects: [SubjectScore]
    var externalEnglishSubjects: [SubjectScore]
    var externalEnglishMemo: String
    var commonTestBorderRate: String
    var minimumPassingScore: String
    var acceptanceRatio: String
    var capacity: String
    var memo: String
    var checklistItems: [ExamChecklistItem]
    var customScheduleItems: [ExamCustomScheduleItem]

    var displayTitle: String {
        faculty.isEmpty ? name : "\(name) \(faculty)"
    }

    var deviationText: String {
        String(format: "%.1f", deviation)
    }

    var resolvedAdmissionCategory: ExamOptionCategory {
        admissionCategory ?? .inferred(from: method)
    }

    var minimumPassingScoreDisplay: String {
        let numerator = minimumScoreNumerator(minimumPassingScore)
        guard !numerator.isEmpty else { return "" }
        guard let denominator = totalPossibleScore else {
            return minimumPassingScore
        }
        return "\(numerator) / \(denominator)"
    }

    private var totalPossibleScore: Int? {
        possibleScoreTotal(subjects + commonTestSubjects + externalEnglishSubjects)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case isHidden
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
        case documentMailingDeadline
        case documentMailingDeadlineRule
        case requiredDocuments
        case requiredDocumentItems
        case resultDate
        case admissionFeeDeadline
        case tuitionDeadline
        case guidelineURL
        case passnaviURL
        case applicationURL
        case subjects
        case commonTestSubjects
        case externalEnglishSubjects
        case externalEnglishMemo
        case commonTestBorderRate
        case minimumPassingScore
        case acceptanceRatio
        case capacity
        case memo
        case checklistItems
        case customScheduleItems
    }

    init(
        id: UUID = UUID(),
        isHidden: Bool = false,
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
        documentMailingDeadline: Date? = nil,
        documentMailingDeadlineRule: DocumentMailingDeadlineRule? = nil,
        requiredDocuments: String,
        requiredDocumentItems: [ExamRequiredDocument]? = nil,
        resultDate: Date?,
        admissionFeeDeadline: Date?,
        tuitionDeadline: Date?,
        guidelineURL: String,
        passnaviURL: String,
        applicationURL: String,
        subjects: [SubjectScore],
        commonTestSubjects: [SubjectScore] = [],
        externalEnglishSubjects: [SubjectScore] = [],
        externalEnglishMemo: String = "",
        commonTestBorderRate: String = "",
        minimumPassingScore: String,
        acceptanceRatio: String,
        capacity: String,
        memo: String,
        checklistItems: [ExamChecklistItem] = ExamChecklistItem.defaultItems,
        customScheduleItems: [ExamCustomScheduleItem] = []
    ) {
        self.id = id
        self.isHidden = isHidden
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
        self.documentMailingDeadline = documentMailingDeadline
        self.documentMailingDeadlineRule = documentMailingDeadline == nil
            ? nil
            : documentMailingDeadlineRule ?? .mustArrive
        self.requiredDocuments = requiredDocuments
        self.requiredDocumentItems = requiredDocumentItems
            ?? ExamRequiredDocument.reconciled(from: requiredDocuments)
        self.resultDate = resultDate
        self.admissionFeeDeadline = admissionFeeDeadline
        self.tuitionDeadline = tuitionDeadline
        self.guidelineURL = guidelineURL
        self.passnaviURL = passnaviURL
        self.applicationURL = applicationURL
        self.subjects = subjects
        self.commonTestSubjects = commonTestSubjects
        self.externalEnglishSubjects = externalEnglishSubjects
        self.externalEnglishMemo = externalEnglishMemo
        self.commonTestBorderRate = commonTestBorderRate
        self.minimumPassingScore = minimumPassingScore
        self.acceptanceRatio = acceptanceRatio
        self.capacity = capacity
        self.memo = memo
        self.checklistItems = checklistItems
        self.customScheduleItems = customScheduleItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
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
        documentMailingDeadline = try container.decodeIfPresent(Date.self, forKey: .documentMailingDeadline)
        documentMailingDeadlineRule = documentMailingDeadline == nil
            ? nil
            : try container.decodeIfPresent(DocumentMailingDeadlineRule.self, forKey: .documentMailingDeadlineRule) ?? .mustArrive
        requiredDocuments = try container.decode(String.self, forKey: .requiredDocuments)
        requiredDocumentItems = try container.decodeIfPresent([ExamRequiredDocument].self, forKey: .requiredDocumentItems)
            ?? ExamRequiredDocument.reconciled(from: requiredDocuments)
        resultDate = try container.decodeIfPresent(Date.self, forKey: .resultDate)
        admissionFeeDeadline = try container.decodeIfPresent(Date.self, forKey: .admissionFeeDeadline)
        tuitionDeadline = try container.decodeIfPresent(Date.self, forKey: .tuitionDeadline)
        guidelineURL = try container.decode(String.self, forKey: .guidelineURL)
        passnaviURL = try container.decode(String.self, forKey: .passnaviURL)
        applicationURL = try container.decode(String.self, forKey: .applicationURL)
        subjects = try container.decode([SubjectScore].self, forKey: .subjects)
        commonTestSubjects = try container.decodeIfPresent([SubjectScore].self, forKey: .commonTestSubjects) ?? []
        externalEnglishSubjects = try container.decodeIfPresent([SubjectScore].self, forKey: .externalEnglishSubjects) ?? []
        externalEnglishMemo = try container.decodeIfPresent(String.self, forKey: .externalEnglishMemo) ?? ""
        commonTestBorderRate = try container.decodeIfPresent(String.self, forKey: .commonTestBorderRate) ?? ""
        minimumPassingScore = try container.decode(String.self, forKey: .minimumPassingScore)
        acceptanceRatio = try container.decode(String.self, forKey: .acceptanceRatio)
        capacity = try container.decode(String.self, forKey: .capacity)
        memo = try container.decode(String.self, forKey: .memo)
        checklistItems = try container.decodeIfPresent([ExamChecklistItem].self, forKey: .checklistItems) ?? ExamChecklistItem.defaultItems
        customScheduleItems = try container.decodeIfPresent([ExamCustomScheduleItem].self, forKey: .customScheduleItems) ?? []
    }

    mutating func reconcileRequiredDocumentItems() {
        requiredDocumentItems = ExamRequiredDocument.reconciled(
            from: requiredDocuments,
            preserving: requiredDocumentItems
        )
    }

    var filledDetailItems: [DetailItem] {
        var items: [DetailItem] = []
        appendDate("入試日程", examDate, "calendar", &items)
        appendApplicationPeriod(&items)
        appendDate("入金締切", paymentDeadline, "yensign.circle", &items)
        appendDocumentMailingDeadline(&items)
        appendText("出願に必要な書類", requiredDocuments, "folder", &items)
        appendDate("合格発表日", resultDate, "flag", &items)
        appendDate("入学金締切", admissionFeeDeadline, "graduationcap", &items)
        appendDate("授業料締切", tuitionDeadline, "creditcard", &items)
        if !subjects.isEmpty {
            items.append(DetailItem(title: "個別試験 科目・配点", value: subjects.map(\.displayText).joined(separator: " / "), systemImage: "book"))
        }
        if !commonTestSubjects.isEmpty {
            items.append(DetailItem(title: "共通テスト 科目・配点", value: commonTestSubjects.map(\.displayText).joined(separator: " / "), systemImage: "checklist"))
        }
        if !externalEnglishSubjects.isEmpty {
            items.append(DetailItem(title: "英語外部試験", value: externalEnglishSubjects.map(\.displayText).joined(separator: " / "), systemImage: "character.book.closed.fill"))
        }
        if resolvedAdmissionCategory == .commonTestOnly || !commonTestSubjects.isEmpty {
            let borderRate = percentageNumber(commonTestBorderRate)
            appendText(
                "共通テスト ボーダー得点率",
                borderRate.isEmpty ? "" : "\(borderRate)%",
                "chart.line.uptrend.xyaxis",
                &items
            )
        }
        appendText("昨年度の合格者最低点", minimumPassingScoreDisplay, "target", &items)
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
            makeEvent(
                kind: .documentMailingDeadline,
                date: documentMailingDeadline,
                title: "書類郵送締切（\(documentMailingDeadlineRule?.rawValue ?? "必着")）"
            ),
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

    private func appendDocumentMailingDeadline(_ items: inout [DetailItem]) {
        guard let documentMailingDeadline else { return }
        items.append(
            DetailItem(
                title: "書類郵送締切",
                value: documentMailingDeadline.formatted(.examDate),
                systemImage: "envelope.fill",
                inlineNote: documentMailingDeadlineRule?.rawValue ?? DocumentMailingDeadlineRule.mustArrive.rawValue
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

func minimumScoreNumerator(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    let firstPart = trimmed.split(whereSeparator: { $0 == "/" || $0 == "／" }).first.map(String.init) ?? trimmed
    return firstPart
        .replacingOccurrences(of: "点", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func scoreValue(_ value: String) -> Int? {
    let normalized = value
        .replacingOccurrences(of: "点", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return Int(normalized)
}

func percentageNumber(_ value: String) -> String {
    value
        .replacingOccurrences(of: "％", with: "%")
        .split(separator: "%", maxSplits: 1, omittingEmptySubsequences: true)
        .first
        .map(String.init)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func possibleScoreTotal(_ subjects: [SubjectScore]) -> Int? {
    guard !subjects.isEmpty else { return nil }
    let values = subjects.compactMap { scoreValue($0.score) }
    guard values.count == subjects.count else { return nil }
    return values.reduce(0, +)
}

struct DetailItem: Identifiable {
    var title: String
    var value: String
    var systemImage: String
    var badge: String? = nil
    var inlineNote: String? = nil
    var countdown: String? = nil

    var id: String { title }
}

struct SchoolDetailSection: Identifiable {
    var title: String
    var systemImage: String
    var items: [DetailItem]
    var context: String? = nil

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

struct UserCalendarEvent: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var universityID: UUID?
    var examOptionIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case universityID
        case examOptionID
        case examOptionIDs
    }

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        universityID: UUID? = nil,
        examOptionIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.universityID = universityID
        self.examOptionIDs = examOptionIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        universityID = try container.decodeIfPresent(UUID.self, forKey: .universityID)
        if let optionIDs = try container.decodeIfPresent([UUID].self, forKey: .examOptionIDs) {
            examOptionIDs = optionIDs
        } else if let optionID = try container.decodeIfPresent(UUID.self, forKey: .examOptionID) {
            examOptionIDs = [optionID]
        } else {
            examOptionIDs = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(universityID, forKey: .universityID)
        try container.encode(examOptionIDs, forKey: .examOptionIDs)
    }

    func examEvent(universities: [UniversityChoice]) -> ExamEvent {
        let university = universities.first { $0.id == universityID }
        let option = university?.examOptions.first { examOptionIDs.contains($0.id) }
        let fallbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        return ExamEvent(
            id: id,
            universityID: university?.id ?? fallbackID,
            examOptionID: option?.id ?? fallbackID,
            schoolName: university?.name ?? "個人予定",
            faculty: option?.faculty ?? "",
            optionName: option?.method ?? "",
            schoolColor: university?.color ?? .slate,
            kind: .custom,
            date: date,
            title: title
        )
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
        if kind == .custom {
            guard includesUniversityName, schoolName != "個人予定" else { return title }
            let university = schoolName.replacingOccurrences(of: "大学", with: "")
            return "\(title) \(university)"
        }

        let university = schoolName.replacingOccurrences(of: "大学", with: "")
        let option = optionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let eventLabel: String
        if kind == .documentMailingDeadline {
            eventLabel = title.contains(DocumentMailingDeadlineRule.postmarkAccepted.rawValue)
                ? "郵送 消印"
                : "郵送 必着"
        } else {
            eventLabel = kind.shortTitle
        }
        if !includesUniversityName {
            return eventLabel
        }
        return option.isEmpty ? "\(eventLabel) \(university)" : "\(eventLabel) \(university)・\(option)"
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
    case custom = "予定"
    case applicationStart = "出願開始"
    case applicationEnd = "出願締切"
    case paymentDeadline = "入金締切"
    case documentMailingDeadline = "書類郵送締切"
    case exam = "入試日程"
    case result = "合格発表"
    case admissionFee = "入学金締切"
    case tuition = "授業料締切"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .custom: "calendar.badge.plus"
        case .applicationStart, .applicationEnd: "doc.text"
        case .paymentDeadline, .admissionFee, .tuition: "yensign.circle"
        case .documentMailingDeadline: "envelope.fill"
        case .exam: "pencil.and.list.clipboard"
        case .result: "flag"
        }
    }

    var shortTitle: String {
        switch self {
        case .all: "予定"
        case .custom: "予定"
        case .applicationStart: "出願"
        case .applicationEnd: "締切"
        case .paymentDeadline: "入金"
        case .documentMailingDeadline: "郵送"
        case .exam: "入試"
        case .result: "発表"
        case .admissionFee: "入学金"
        case .tuition: "授業料"
        }
    }

    var calendarPriority: Int {
        switch self {
        case .exam: 0
        case .applicationEnd, .documentMailingDeadline: 1
        case .paymentDeadline, .admissionFee, .tuition: 2
        case .result: 3
        case .custom: 4
        case .applicationStart, .all: 5
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
    @Environment(\.openAppSidebar) private var openSidebar

    var title: String
    var subtitle: String? = nil
    var leadingSystemImage: String? = nil
    var trailingSystemImage: String? = nil
    var showsSidebar = true
    var leadingAction: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            VStack(alignment: .center, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, leadingSystemImage == nil ? 54 : 100)

            HStack(spacing: 8) {
                if showsSidebar {
                    barButton(
                        systemImage: "line.3.horizontal",
                        accessibilityLabel: "サイドバーを開く",
                        action: openSidebar
                    )
                }

                if let leadingSystemImage {
                    barButton(
                        systemImage: leadingSystemImage,
                        accessibilityLabel: "戻る",
                        action: leadingAction
                    )
                }

                Spacer(minLength: 0)

                if let trailingSystemImage {
                    barButton(
                        systemImage: trailingSystemImage,
                        accessibilityLabel: nil,
                        action: trailingAction
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.deepNavy)
    }

    private func barButton(
        systemImage: String,
        accessibilityLabel: String?,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.86 : 1)
        .accessibilityLabel(accessibilityLabel ?? systemImage)
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
                                SchoolDetailView(
                                    school: binding(for: school),
                                    onDelete: {
                                        schools.removeAll { $0.id == school.id }
                                    }
                                )
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
    private enum DetailTab: String, CaseIterable, Identifiable {
        case information = "登録情報"
        case scores = "配点"
        case checklist = "やること"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Binding var school: ExamSchool
    var fixedUniversity: UniversityChoice? = nil
    var onDelete: (() -> Void)? = nil
    @State private var showingEditSheet = false
    @State private var selectedTab = DetailTab.information
    @State private var showingActionMenu = false
    @State private var showingHideConfirmation = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "詳細",
                subtitle: school.name,
                leadingSystemImage: "chevron.left",
                trailingSystemImage: "ellipsis",
                showsSidebar: false,
                leadingAction: { dismiss() },
                trailingAction: { showingActionMenu = true }
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    SchoolDetailSummary(school: school)

                    if let nextEvent {
                        NextExamEventBanner(event: nextEvent, tint: school.color.color)
                    }

                    Picker("表示内容", selection: $selectedTab) {
                        ForEach(DetailTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("入試方式の詳細表示")

                    switch selectedTab {
                    case .information:
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
                    case .scores:
                        ExamScoreView(
                            category: school.resolvedAdmissionCategory,
                            subjects: school.subjects,
                            commonTestSubjects: school.commonTestSubjects,
                            externalEnglishSubjects: school.externalEnglishSubjects,
                            externalEnglishMemo: school.externalEnglishMemo,
                            commonTestBorderRate: school.commonTestBorderRate,
                            minimumPassingScore: school.minimumPassingScoreDisplay,
                            tint: school.color.color,
                            onEdit: { showingEditSheet = true }
                        )

                    case .checklist:
                        ExamChecklistView(
                            items: $school.checklistItems,
                            requiredDocuments: $school.requiredDocumentItems,
                            tint: school.color.color
                        )
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
        .confirmationDialog(
            "入試方式の操作",
            isPresented: $showingActionMenu,
            titleVisibility: .visible
        ) {
            Button("編集") {
                showingEditSheet = true
            }
            Button("非表示にする", role: .destructive) {
                showingHideConfirmation = true
            }
            if onDelete != nil {
                Button("削除する", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "この入試方式を非表示にしますか？",
            isPresented: $showingHideConfirmation,
            titleVisibility: .visible
        ) {
            Button("非表示にする", role: .destructive) {
                school.isHidden = true
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("カレンダーと戦略マップからも非表示になります。サイドバーの「非表示の項目を見る」から復元できます。")
        }
        .confirmationDialog(
            "この入試方式を削除しますか？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この方式だけを削除します。削除した情報は元に戻せません。")
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
            SchoolDetailSection(
                title: "日程",
                systemImage: "calendar",
                items: scheduleItems,
                context: scheduleYearLabel
            ),
            SchoolDetailSection(title: "出願情報", systemImage: "doc.text.fill", items: applicationItems),
            SchoolDetailSection(title: "試験情報", systemImage: "pencil.and.list.clipboard", items: examItems),
            SchoolDetailSection(title: "メモ", systemImage: "note.text", items: noteItems)
        ].filter { !$0.items.isEmpty }
    }

    private var scheduleItems: [DetailItem] {
        let standardItems = [
            dateItem("入試日程", school.examDate, "pencil.and.list.clipboard"),
            applicationPeriodItem,
            dateItem("入金締切", school.paymentDeadline, "yensign.circle"),
            documentMailingDeadlineItem,
            dateItem("合格発表日", school.resultDate, "flag.fill"),
            dateItem("入学金締切", school.admissionFeeDeadline, "graduationcap.fill"),
            dateItem("授業料締切", school.tuitionDeadline, "creditcard.fill")
        ].compactMap { $0 }
        let customItems = school.customScheduleItems
            .sorted { $0.date < $1.date }
            .map { item in
                DetailItem(
                    title: item.title,
                    value: formattedScheduleDate(item.date),
                    systemImage: "calendar.badge.plus",
                    countdown: item.date.countdownText
                )
            }
        return standardItems + customItems
    }

    private var applicationPeriodItem: DetailItem? {
        guard school.applicationStart != nil || school.applicationEnd != nil else { return nil }
        return DetailItem(
            title: "出願期間",
            value: Date.applicationPeriodText(
                start: school.applicationStart,
                end: school.applicationEnd,
                includeYear: scheduleUsesMultipleYears
            ),
            systemImage: "arrow.left.and.right",
            badge: Date.applicationPeriodDaysText(start: school.applicationStart, end: school.applicationEnd),
            countdown: (school.applicationEnd ?? school.applicationStart)?.countdownText
        )
    }

    private var documentMailingDeadlineItem: DetailItem? {
        guard let date = school.documentMailingDeadline else { return nil }
        return DetailItem(
            title: "書類郵送締切",
            value: formattedScheduleDate(date),
            systemImage: "envelope.fill",
            inlineNote: school.documentMailingDeadlineRule?.rawValue ?? DocumentMailingDeadlineRule.mustArrive.rawValue,
            countdown: date.countdownText
        )
    }

    private var scheduleDates: [Date] {
        [
            school.examDate,
            school.applicationStart,
            school.applicationEnd,
            school.paymentDeadline,
            school.documentMailingDeadline,
            school.resultDate,
            school.admissionFeeDeadline,
            school.tuitionDeadline
        ].compactMap { $0 } + school.customScheduleItems.map(\.date)
    }

    private var scheduleYears: [Int] {
        Array(Set(scheduleDates.map { Calendar.current.component(.year, from: $0) })).sorted()
    }

    private var scheduleUsesMultipleYears: Bool {
        scheduleYears.count > 1
    }

    private var scheduleYearLabel: String? {
        guard let first = scheduleYears.first else { return nil }
        guard let last = scheduleYears.last, first != last else { return "\(first)年" }
        return "\(first)–\(last)年"
    }

    private func formattedScheduleDate(_ date: Date) -> String {
        date.formatted(scheduleUsesMultipleYears ? .examDate : .monthDayWeekday)
    }

    private var applicationItems: [DetailItem] {
        [textItem("必要書類", school.requiredDocuments, "folder.fill")].compactMap { $0 }
    }

    private var examItems: [DetailItem] {
        [
            textItem("倍率", school.acceptanceRatio, "chart.bar.fill"),
            textItem("募集人数", school.capacity, "person.3.fill")
        ].compactMap { $0 }
    }

    private var noteItems: [DetailItem] {
        [textItem("メモ", school.memo, "square.and.pencil")].compactMap { $0 }
    }

    private func dateItem(_ title: String, _ date: Date?, _ systemImage: String) -> DetailItem? {
        guard let date else { return nil }
        return DetailItem(
            title: title,
            value: formattedScheduleDate(date),
            systemImage: systemImage,
            countdown: date.countdownText
        )
    }

    private func textItem(_ title: String, _ value: String, _ systemImage: String) -> DetailItem? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return DetailItem(title: title, value: value, systemImage: systemImage)
    }
}

struct ExamScoreView: View {
    var category: ExamOptionCategory
    var subjects: [SubjectScore]
    var commonTestSubjects: [SubjectScore]
    var externalEnglishSubjects: [SubjectScore]
    var externalEnglishMemo: String
    var commonTestBorderRate: String
    var minimumPassingScore: String
    var tint: Color
    var onEdit: () -> Void

    private var hasMinimumPassingScore: Bool {
        !minimumPassingScore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasCommonTestBorderRate: Bool {
        !percentageNumber(commonTestBorderRate).isEmpty
    }

    private var usesCommonTest: Bool {
        category == .commonTestOnly || !commonTestSubjects.isEmpty
    }

    private var commonTestBorderRateDisplay: String {
        let value = percentageNumber(commonTestBorderRate)
        return value.isEmpty ? "" : "\(value)%"
    }

    private var isEmpty: Bool {
        visibleSubjects.isEmpty && commonTestSubjects.isEmpty && externalEnglishSubjects.isEmpty && !hasMinimumPassingScore && !hasCommonTestBorderRate
    }

    private var visibleSubjects: [SubjectScore] {
        category == .general ? subjects : []
    }

    private var visibleSubjectCount: Int {
        visibleSubjects.count + commonTestSubjects.count + externalEnglishSubjects.count
    }

    private var emptyDescription: String {
        category == .general
            ? "共通テスト・英語外部試験・個別試験の配点を登録できます"
            : "共通テストと英語外部試験の配点を登録できます"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("科目・配点")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(visibleSubjectCount)項目")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.top, 4)

            if isEmpty {
                Button(action: onEdit) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("配点を追加")
                                .font(.subheadline.weight(.bold))
                            Text(emptyDescription)
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(tint)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                if !visibleSubjects.isEmpty {
                    ExamScoreCard(
                        title: "個別試験",
                        systemImage: "book.closed.fill",
                        subjects: visibleSubjects,
                        tint: tint
                    )
                }

                if !commonTestSubjects.isEmpty {
                    ExamScoreCard(
                        title: "共通テスト",
                        systemImage: "checklist",
                        subjects: commonTestSubjects,
                        tint: tint
                    )
                }

                if !externalEnglishSubjects.isEmpty {
                    ExamScoreCard(
                        title: "英語外部試験",
                        systemImage: "character.book.closed.fill",
                        subjects: externalEnglishSubjects,
                        tint: tint
                    )

                    if !externalEnglishMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "note.text")
                                .foregroundStyle(tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("英語外部試験のメモ")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.primaryText)
                                Text(externalEnglishMemo)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                if hasMinimumPassingScore || (usesCommonTest && hasCommonTestBorderRate) {
                    VStack(spacing: 0) {
                        if hasMinimumPassingScore {
                            HStack(spacing: 12) {
                                Image(systemName: "target")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(tint)
                                    .frame(width: 36, height: 36)
                                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                                Text("昨年度の合格者最低点")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Text(minimumPassingScore)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(tint)
                                    .monospacedDigit()
                            }
                            .padding(15)
                        }

                        if hasMinimumPassingScore && usesCommonTest && hasCommonTestBorderRate {
                            Divider()
                                .padding(.horizontal, 15)
                        }

                        if usesCommonTest && hasCommonTestBorderRate {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(tint)
                                    .frame(width: 36, height: 36)
                                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                                Text("共通テスト ボーダー得点率")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Text(commonTestBorderRateDisplay)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(tint)
                            }
                            .padding(15)
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct ExamScoreCard: View {
    var title: String
    var systemImage: String
    var subjects: [SubjectScore]
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(subjects.count)科目")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()

            ForEach(subjects) { subject in
                HStack(spacing: 12) {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                    Text(subject.subject.isEmpty ? "科目名未入力" : subject.subject)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Text(subject.score.isEmpty ? "未入力" : subject.score)
                        .font(.body.weight(.bold))
                        .foregroundStyle(subject.score.isEmpty ? Color.secondaryText : tint)
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                if subject.id != subjects.last?.id {
                    Divider().padding(.leading, 35)
                }
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ExamChecklistView: View {
    @Binding var items: [ExamChecklistItem]
    @Binding var requiredDocuments: [ExamRequiredDocument]
    var tint: Color

    @State private var draftTitle = ""
    @State private var itemPendingDeletion: ExamChecklistItem?
    @FocusState private var isAddingTask: Bool

    private var completedCount: Int {
        items.filter(\.isCompleted).count
            + (showsRequiredDocuments ? requiredDocuments.filter(\.isCompleted).count : 0)
    }

    private var totalCount: Int {
        items.count + (showsRequiredDocuments ? requiredDocuments.count : 0)
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var showsRequiredDocuments: Bool {
        !requiredDocuments.isEmpty && items.contains { $0.title == "書類を郵送" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(completedCount == totalCount && totalCount > 0 ? "準備完了" : "受験準備")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.primaryText)
                        Text("\(totalCount)件中 \(completedCount)件完了")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }

                ProgressView(value: progress)
                    .tint(tint)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 8))

            if items.isEmpty {
                ContentUnavailableView(
                    "やることはありません",
                    systemImage: "checklist",
                    description: Text("下の入力欄から追加できます")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
            } else {
                List {
                    ForEach($items) { $item in
                        checklistRow(item: $item)
                            .listRowInsets(EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 12))
                            .listRowBackground(Color.white)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    itemPendingDeletion = item
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .dropDestination(for: String.self) { identifiers, location in
                                moveDraggedItem(
                                    identifiers,
                                    around: item.id,
                                    placeAfterTarget: location.y > 29
                                )
                            }
                    }
                    .onMove(perform: moveItems)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: checklistHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.headline)
                    .foregroundStyle(tint)

                TextField("やることを追加", text: $draftTitle)
                    .font(.body)
                    .focused($isAddingTask)
                    .submitLabel(.done)
                    .onSubmit(addTask)

                Button("追加", action: addTask)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .disabled(trimmedDraftTitle.isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tint.opacity(isAddingTask ? 0.42 : 0.16), lineWidth: 1)
            }
        }
        .alert(
            itemPendingDeletion.map { "「\($0.title)」を削除しますか？" } ?? "やることを削除しますか？",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            )
        ) {
            Button("削除", role: .destructive) {
                guard let itemPendingDeletion else { return }
                items.removeAll { $0.id == itemPendingDeletion.id }
                self.itemPendingDeletion = nil
            }
            Button("キャンセル", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    private func checklistRow(item: Binding<ExamChecklistItem>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        item.wrappedValue.isCompleted.toggle()
                    }
                } label: {
                    Image(systemName: item.wrappedValue.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.wrappedValue.isCompleted ? tint : Color.secondaryText.opacity(0.55))
                        .frame(width: 30, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    item.wrappedValue.isCompleted
                        ? "\(item.wrappedValue.title)を未完了にする"
                        : "\(item.wrappedValue.title)を完了にする"
                )

                Text(item.wrappedValue.title)
                    .font(.body.weight(item.wrappedValue.isCompleted ? .regular : .medium))
                    .foregroundStyle(item.wrappedValue.isCompleted ? Color.secondaryText : Color.primaryText)
                    .strikethrough(item.wrappedValue.isCompleted, color: Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "line.3.horizontal")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.secondaryText.opacity(0.7))
                    .frame(width: 32, height: 36)
                    .contentShape(Rectangle())
                    .draggable(item.wrappedValue.id.uuidString) {
                        Text(item.wrappedValue.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("\(item.wrappedValue.title)を並び替え")
            }
            .frame(minHeight: 44)

            if item.wrappedValue.title == "書類を郵送" && !requiredDocuments.isEmpty {
                VStack(spacing: 0) {
                    ForEach($requiredDocuments) { $document in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                document.isCompleted.toggle()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: document.isCompleted ? "checkmark.square.fill" : "square")
                                    .font(.body)
                                    .foregroundStyle(document.isCompleted ? tint : Color.secondaryText.opacity(0.55))
                                    .frame(width: 24)

                                Text(document.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(document.isCompleted ? Color.secondaryText : Color.primaryText)
                                    .strikethrough(document.isCompleted, color: Color.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.leading, 40)
                            .padding(.trailing, 32)
                            .frame(minHeight: 38)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            document.isCompleted
                                ? "必要書類の\(document.title)を未完了にする"
                                : "必要書類の\(document.title)を完了にする"
                        )
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 5)
                .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .accessibilityAction(named: "上へ移動") {
            moveItem(id: item.wrappedValue.id, offset: -1)
        }
        .accessibilityAction(named: "下へ移動") {
            moveItem(id: item.wrappedValue.id, offset: 1)
        }
    }

    private var trimmedDraftTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var checklistHeight: CGFloat {
        CGFloat(items.count) * 58
            + (showsRequiredDocuments ? CGFloat(requiredDocuments.count) * 38 + 7 : 0)
    }

    private func addTask() {
        let title = trimmedDraftTitle
        guard !title.isEmpty else { return }
        items.append(ExamChecklistItem(title: title))
        draftTitle = ""
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        withAnimation(.snappy) {
            items.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func moveDraggedItem(
        _ identifiers: [String],
        around targetID: UUID,
        placeAfterTarget: Bool
    ) -> Bool {
        guard
            let sourceID = identifiers.compactMap(UUID.init(uuidString:)).first,
            sourceID != targetID,
            let sourceIndex = items.firstIndex(where: { $0.id == sourceID })
        else { return false }

        let movedItem = items.remove(at: sourceIndex)
        guard let updatedTargetIndex = items.firstIndex(where: { $0.id == targetID }) else {
            items.insert(movedItem, at: min(sourceIndex, items.endIndex))
            return false
        }

        let insertionIndex = placeAfterTarget ? updatedTargetIndex + 1 : updatedTargetIndex
        withAnimation(.snappy) {
            items.insert(movedItem, at: min(insertionIndex, items.endIndex))
        }
        return true
    }

    private func moveItem(id: UUID, offset: Int) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let destinationIndex = sourceIndex + offset
        guard items.indices.contains(destinationIndex) else { return }
        withAnimation(.snappy) {
            items.swapAt(sourceIndex, destinationIndex)
        }
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
                    HStack(spacing: 7) {
                        Text(item.value)
                            .font(.subheadline.weight(item.title.contains("締切") || item.title == "入試日程" || item.title == "出願期間" ? .semibold : .regular))
                            .foregroundStyle(Color.primaryText)
                            .textSelection(.enabled)

                        if let inlineNote = item.inlineNote {
                            Text(inlineNote)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }

                        if let countdown = item.countdown {
                            Text(countdown)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.31))
                                .monospacedDigit()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(red: 1.0, green: 0.91, blue: 0.93), in: Capsule())
                        }
                    }
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
                if let context = section.context {
                    Text(context)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                } else {
                    Text("\(section.items.count)項目")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                }
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

    private enum EditorTab: String, CaseIterable, Identifiable {
        case information = "登録情報"
        case scores = "配点"

        var id: String { rawValue }
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
    @State private var selectedEditorTab = EditorTab.information
    @FocusState private var focusedField: FocusedField?
    var onSave: (ExamSchool) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("編集内容", selection: $selectedEditorTab) {
                    ForEach(EditorTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white)
                .accessibilityLabel("入試方式の編集内容")

                Form {
                    if selectedEditorTab == .information {
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
                    DocumentMailingDeadlinePicker(
                        date: $school.documentMailingDeadline,
                        rule: $school.documentMailingDeadlineRule
                    )
                    OptionalDatePicker(title: "入金締切", date: $school.paymentDeadline)
                    OptionalDatePicker(title: "合格発表日", date: $school.resultDate)
                    OptionalDatePicker(title: "入学金締切", date: $school.admissionFeeDeadline)
                    OptionalDatePicker(title: "授業料締切", date: $school.tuitionDeadline)
                }

                editorSection(
                    section: .application,
                    title: "出願情報",
                    subtitle: "出願に必要な書類",
                    systemImage: "doc.text.fill",
                    completedCount: applicationInformationCount
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        EditorTextField(
                            title: "必要書類",
                            placeholder: "調査書、写真、志望理由書など",
                            systemImage: "folder.fill",
                            text: $school.requiredDocuments,
                            axis: .vertical,
                            verticalPadding: 0
                        )
                        Label("「、」または改行で区切ると、やることリストの小項目になります", systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                editorSection(
                    section: .exam,
                    title: "試験実績",
                    subtitle: "倍率と募集人数",
                    systemImage: "pencil.and.list.clipboard",
                    completedCount: performanceInformationCount
                ) {
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
                    } else {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: school.resolvedAdmissionCategory == .commonTestOnly ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                                    .font(.headline)
                                    .foregroundStyle(school.color.color)
                                    .frame(width: 38, height: 38)
                                    .background(school.color.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(school.resolvedAdmissionCategory.rawValue)
                                        .font(.headline)
                                    Text(scoreEditorDescription)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }

                        if school.resolvedAdmissionCategory == .general {
                            Section {
                                SubjectEditor(
                                    title: "個別試験の科目ごとの配点",
                                    systemImage: "book.closed.fill",
                                    addPlaceholder: "個別試験の科目を追加",
                                    subjects: $school.subjects
                                )
                            }
                        }

                        Section {
                            CommonTestSubjectEditor(
                                subjects: $school.commonTestSubjects,
                                isOptional: school.resolvedAdmissionCategory == .general
                            )
                        }

                        Section {
                            SubjectEditor(
                                title: "英語外部試験の配点",
                                systemImage: "character.book.closed.fill",
                                addPlaceholder: "例：英検・TEAPを追加",
                                subjects: $school.externalEnglishSubjects,
                                isOptional: school.resolvedAdmissionCategory == .general
                            )

                            if !school.externalEnglishSubjects.isEmpty {
                                EditorTextField(
                                    title: "英語外部試験のメモ",
                                    placeholder: "例：スコアを各科目の点数に換算",
                                    systemImage: "note.text",
                                    text: $school.externalEnglishMemo,
                                    axis: .vertical
                                )
                            }
                        }

                        if school.resolvedAdmissionCategory == .commonTestOnly || !school.commonTestSubjects.isEmpty {
                            Section {
                                PercentageEditor(
                                    title: "共通テスト ボーダー得点率",
                                    text: Binding(
                                        get: { percentageNumber(school.commonTestBorderRate) },
                                        set: { school.commonTestBorderRate = $0 }
                                    ),
                                    tint: school.color.color
                                )
                            }
                        }

                        Section {
                            MinimumPassingScoreEditor(
                                text: Binding(
                                    get: { minimumScoreNumerator(school.minimumPassingScore) },
                                    set: { school.minimumPassingScore = $0 }
                                ),
                                total: possibleScoreTotal(school.subjects + school.commonTestSubjects + school.externalEnglishSubjects),
                                tint: school.color.color
                            )
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .scrollDismissesKeyboard(.interactively)
            }
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
                        school.reconcileRequiredDocumentItems()
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
            school.documentMailingDeadline,
            school.resultDate,
            school.admissionFeeDeadline,
            school.tuitionDeadline
        ].compactMap { $0 }.count
        let applicationPeriodCount = school.applicationStart != nil || school.applicationEnd != nil ? 1 : 0
        return dateCount + applicationPeriodCount
    }

    private var applicationInformationCount: Int {
        nonEmptyCount([school.requiredDocuments])
    }

    private var examInformationCount: Int {
        let individualCount = school.resolvedAdmissionCategory == .general && !school.subjects.isEmpty ? 1 : 0
        return individualCount
            + (school.commonTestSubjects.isEmpty ? 0 : 1)
            + (school.externalEnglishSubjects.isEmpty ? 0 : 1)
            + nonEmptyCount([school.externalEnglishMemo])
            + nonEmptyCount([school.commonTestBorderRate])
            + nonEmptyCount([
            school.minimumPassingScore,
            school.acceptanceRatio,
            school.capacity
        ])
    }

    private var performanceInformationCount: Int {
        nonEmptyCount([school.acceptanceRatio, school.capacity])
    }

    private var scoreEditorDescription: String {
        school.resolvedAdmissionCategory == .general
            ? "共通テスト・英語外部試験・個別試験"
            : "共通テスト・英語外部試験"
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

struct DocumentMailingDeadlinePicker: View {
    @Binding var date: Date?
    @Binding var rule: DocumentMailingDeadlineRule?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("書類郵送締切", systemImage: "envelope.fill")
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
                        rule = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondaryText.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("書類郵送締切を削除")
                } else {
                    Button {
                        date = .demoToday
                        rule = .mustArrive
                    } label: {
                        Label("追加", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }

            if date != nil {
                Picker("郵送締切の基準", selection: ruleBinding) {
                    ForEach(DocumentMailingDeadlineRule.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.vertical, 3)
    }

    private var ruleBinding: Binding<DocumentMailingDeadlineRule> {
        Binding(
            get: { rule ?? .mustArrive },
            set: { rule = $0 }
        )
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
    var isOptional = false
    @State private var newSubject = ""
    @State private var newScore = ""

    var body: some View {
        if isOptional && subjects.isEmpty {
            Button {
                subjects.append(SubjectScore(subject: "", score: ""))
            } label: {
                Label(title + "を追加", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.deepNavy)
        } else {
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
}

private struct CommonTestSubjectGroup: Identifiable {
    let title: String
    let subjects: [String]

    var id: String { title }
}

private enum CommonTestSubjectCatalog {
    static let japaneseWhole = "国語"
    static let japaneseParts = ["現代文", "古文", "漢文"]

    static let socialGroup = CommonTestSubjectGroup(
        title: "社会",
        subjects: [
            "地理総合・地理探究",
            "歴史総合・日本史探究",
            "歴史総合・世界史探究",
            "公共・倫理",
            "公共・政治・経済",
            "地理総合／歴史総合／公共"
        ]
    )
    static let foreignLanguageGroup = CommonTestSubjectGroup(
        title: "外国語",
        subjects: ["英語（リーディング）", "英語（リスニング）", "ドイツ語", "フランス語", "中国語", "韓国語"]
    )
    static let scienceGroup = CommonTestSubjectGroup(
        title: "理科",
        subjects: ["物理基礎", "化学基礎", "生物基礎", "地学基礎", "物理", "化学", "生物", "地学"]
    )
    static let mathematicsGroup = CommonTestSubjectGroup(
        title: "数学",
        subjects: ["数学I・A", "数学I", "数学II・B・C"]
    )
    static let informationGroup = CommonTestSubjectGroup(
        title: "情報",
        subjects: ["情報I"]
    )

    static let secondDayGroups = [scienceGroup, mathematicsGroup, informationGroup]

    static let allSubjects = socialGroup.subjects
        + japaneseParts
        + foreignLanguageGroup.subjects
        + secondDayGroups.flatMap(\.subjects)
    static let subjectSet = Set(allSubjects + [japaneseWhole])

    static func normalizedSelection<S: Sequence>(from subjects: S) -> Set<String> where S.Element == String {
        var selection = Set(subjects).intersection(subjectSet)
        if selection.remove(japaneseWhole) != nil {
            selection.formUnion(japaneseParts)
        }
        return selection
    }
}

struct CommonTestSubjectEditor: View {
    @Binding var subjects: [SubjectScore]
    var isOptional = false

    var body: some View {
        Group {
            if isOptional && subjects.isEmpty {
                NavigationLink {
                    CommonTestSubjectPickerView(
                        initialSelection: [],
                        onApply: applySelection
                    )
                } label: {
                    Label("共通テストを追加", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.deepNavy)
            } else {
                EditorFieldLabel(title: "共通テストの科目ごとの配点", systemImage: "checklist")

                NavigationLink {
                    CommonTestSubjectPickerView(
                        initialSelection: CommonTestSubjectCatalog.normalizedSelection(from: subjects.map(\.subject)),
                        onApply: applySelection
                    )
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist.checked")
                        Text(subjects.isEmpty ? "科目を選択" : "選択科目を変更")
                            .fontWeight(.semibold)
                        Spacer()
                        if !subjects.isEmpty {
                            Text("\(subjects.count)科目")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(Color.deepNavy)
                .padding(.vertical, 6)

                if subjects.isEmpty {
                    Text("共通テストで利用する科目を選ぶと、ここで配点を入力できます")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                } else {
                    ForEach($subjects) { $subject in
                        HStack(spacing: 10) {
                            Text(subject.subject)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.deepNavy)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                            .accessibilityLabel("\(subject.subject)を削除")
                        }
                    }
                }
            }
        }
    }

    private func applySelection(_ selection: Set<String>) {
        let existingByName = Dictionary(
            subjects.map { ($0.subject, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let selectedCatalogSubjects: [SubjectScore] = CommonTestSubjectCatalog.allSubjects.compactMap { name -> SubjectScore? in
            guard selection.contains(name) else { return nil }
            return existingByName[name] ?? SubjectScore(subject: name, score: "")
        }
        let legacySubjects = subjects.filter { !CommonTestSubjectCatalog.subjectSet.contains($0.subject) }
        subjects = selectedCatalogSubjects + legacySubjects
    }
}

struct CommonTestSubjectPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String>
    let onApply: (Set<String>) -> Void

    init(initialSelection: Set<String>, onApply: @escaping (Set<String>) -> Void) {
        _selection = State(initialValue: initialSelection)
        self.onApply = onApply
    }

    var body: some View {
        List {
            Section {
                Text("利用する科目にチェックを入れてください。配点は選択後の画面で入力できます。")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }

            dayHeader("1日目")
            subjectGroupSection(CommonTestSubjectCatalog.socialGroup)

            Section("国語") {
                japaneseParentRow

                ForEach(CommonTestSubjectCatalog.japaneseParts, id: \.self) { subject in
                    subjectRow(subject, isChild: true)
                }
            }

            subjectGroupSection(CommonTestSubjectCatalog.foreignLanguageGroup)

            dayHeader("2日目")
            ForEach(CommonTestSubjectCatalog.secondDayGroups) { group in
                subjectGroupSection(group)
            }
        }
        .navigationTitle("共通テスト科目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("反映") {
                    onApply(selection)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func dayHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: title == "1日目" ? "1.circle.fill" : "2.circle.fill")
                .foregroundStyle(Color.uniexamIndigo)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.deepNavy)
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 4, trailing: 4))
        .accessibilityAddTraits(.isHeader)
    }

    private func subjectGroupSection(_ group: CommonTestSubjectGroup) -> some View {
        Section(group.title) {
            ForEach(group.subjects, id: \.self) { subject in
                subjectRow(subject)
            }
        }
    }

    private var japaneseParentRow: some View {
        let selectedCount = CommonTestSubjectCatalog.japaneseParts.filter(selection.contains).count
        let isFullySelected = selectedCount == CommonTestSubjectCatalog.japaneseParts.count
        let imageName = isFullySelected ? "checkmark.circle.fill" : (selectedCount > 0 ? "minus.circle.fill" : "circle")

        return Button {
            if isFullySelected {
                selection.subtract(CommonTestSubjectCatalog.japaneseParts)
            } else {
                selection.formUnion(CommonTestSubjectCatalog.japaneseParts)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: imageName)
                    .font(.title3)
                    .foregroundStyle(selectedCount > 0 ? Color.uniexamIndigo : Color.secondaryText.opacity(0.55))
                Text("国語")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.deepNavy)
                Spacer()
                if selectedCount > 0 && !isFullySelected {
                    Text("\(selectedCount)/3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("国語")
        .accessibilityValue(isFullySelected ? "3項目すべて選択済み" : "3項目中\(selectedCount)項目を選択")
    }

    private func subjectRow(_ subject: String, isChild: Bool = false) -> some View {
        let isSelected = selection.contains(subject)
        return Button {
            toggle(subject)
        } label: {
            HStack(spacing: 12) {
                if isChild {
                    Rectangle()
                        .fill(Color.uniexamIndigo.opacity(0.18))
                        .frame(width: 2, height: 28)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.uniexamIndigo : Color.secondaryText.opacity(0.55))
                Text(subject)
                    .foregroundStyle(Color.deepNavy)
                Spacer()
            }
            .padding(.leading, isChild ? 14 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subject)
        .accessibilityValue(isSelected ? "選択済み" : "未選択")
    }

    private func toggle(_ subject: String) {
        if selection.contains(subject) {
            selection.remove(subject)
        } else {
            selection.insert(subject)
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
    var verticalPadding: CGFloat = 3

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
        .padding(.vertical, verticalPadding)
    }
}

struct MinimumPassingScoreEditor: View {
    @Binding var text: String
    var total: Int?
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(
                title: "昨年度の合格者最低点",
                systemImage: "target"
            )

            HStack(spacing: 8) {
                TextField("得点", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)

                Text("/")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)

                Text(total.map(String.init) ?? "—")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(minWidth: 52, alignment: .leading)
            }
        }
        .padding(.vertical, 3)
    }
}

struct PercentageEditor: View {
    var title: String
    @Binding var text: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(title: title, systemImage: "chart.line.uptrend.xyaxis")

            HStack(spacing: 8) {
                TextField("例：75", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                Text("%")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
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
        .onReceive(
            NotificationCenter.default.publisher(for: .uniexamCustomColorsDidChange)
        ) { _ in
            customColors = CustomSchoolColorPersistence.load()
        }
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
    @Binding var universities: [UniversityChoice]
    @Binding var customEvents: [UserCalendarEvent]
    @State private var selectedDate: Date?
    @State private var displayedMonth = Date.from(year: 2027, month: 2, day: 1)
    @State private var selectedKind: EventKind = .all
    @State private var selectedUniversityID: UUID?
    @State private var selectedOptionID: UUID?
    @State private var showingFilters = false
    @State private var presentedDay: CalendarDaySelection?

    private let calendar = Calendar.current

    private var schools: [ExamSchool] {
        universities
            .filter { !$0.isHidden }
            .flatMap { $0.joinedSchools.filter { !$0.isHidden } }
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

                Text("日程をダブルタップすると詳細が表示できます")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)

                ScrollView {
                    MonthGridView(
                        monthStart: displayedMonth,
                        selectedDate: $selectedDate,
                        events: filteredEvents,
                        applicationRanges: visibleApplicationRanges,
                        onOpenDate: { presentedDay = CalendarDaySelection(date: $0) },
                        onPreviousMonth: { moveMonth(by: -1) },
                        onNextMonth: { moveMonth(by: 1) }
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 12)
                }
                .background(Color.appBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingFilters) {
                CalendarFilterSheet(
                    universities: universities.filter { !$0.isHidden },
                    selectedKind: $selectedKind,
                    selectedUniversityID: $selectedUniversityID,
                    selectedOptionID: $selectedOptionID
                )
            }
            .sheet(item: $presentedDay) { selection in
                CalendarDayAgendaSheet(
                    date: selection.date,
                    events: events(on: selection.date),
                    applicationRanges: activeApplicationRanges(on: selection.date),
                    schools: schools,
                    universities: universities.filter { !$0.isHidden },
                    onSave: saveCustomEvent,
                    onDelete: deleteCustomEvent
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
        let registeredEvents = schools.flatMap(\.events).filter { event in
            let kindMatches = selectedKind == .all || event.kind == selectedKind
            let universityMatches = selectedUniversityID == nil || event.universityID == selectedUniversityID
            let optionMatches = selectedOptionID == nil || event.examOptionID == selectedOptionID
            return kindMatches && universityMatches && optionMatches
        }
        let userEvents = customEvents
            .filter { event in
                let kindMatches = selectedKind == .all || selectedKind == .custom
                let universityMatches = selectedUniversityID == nil || event.universityID == selectedUniversityID
                let optionMatches = selectedOptionID == nil || event.examOptionIDs.contains(selectedOptionID!)
                let universityIsVisible = event.universityID == nil
                    || universities.first(where: { $0.id == event.universityID })?.isHidden != true
                let optionIsVisible = event.examOptionIDs.allSatisfy { optionID in
                    universities
                        .flatMap(\.examOptions)
                        .first(where: { $0.id == optionID })?.isHidden != true
                }
                return kindMatches && universityMatches && optionMatches && universityIsVisible && optionIsVisible
            }
            .map { $0.examEvent(universities: universities.filter { !$0.isHidden }) }
        return registeredEvents + userEvents
    }

    private func saveCustomEvent(_ event: UserCalendarEvent) {
        customEvents.append(event)
        guard let universityID = event.universityID,
              let universityIndex = universities.firstIndex(where: { $0.id == universityID }) else { return }

        let scheduleItem = ExamCustomScheduleItem(id: event.id, title: event.title, date: event.date)
        for optionID in event.examOptionIDs {
            guard let optionIndex = universities[universityIndex].examOptions.firstIndex(where: { $0.id == optionID }) else {
                continue
            }
            universities[universityIndex].examOptions[optionIndex].customScheduleItems.removeAll { $0.id == event.id }
            universities[universityIndex].examOptions[optionIndex].customScheduleItems.append(scheduleItem)
        }
    }

    private func deleteCustomEvent(_ eventID: UUID) {
        customEvents.removeAll { $0.id == eventID }
        for universityIndex in universities.indices {
            for optionIndex in universities[universityIndex].examOptions.indices {
                universities[universityIndex].examOptions[optionIndex].customScheduleItems.removeAll { $0.id == eventID }
            }
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

    private func activeApplicationRanges(on date: Date) -> [CalendarApplicationRange] {
        visibleApplicationRanges.filter { range in
            range.contains(date, calendar: calendar)
                && !range.isStart(date, calendar: calendar)
                && !range.isEnd(date, calendar: calendar)
        }
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
        selectedDate = nil
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

struct AddCalendarEventSheet: View {
    @State private var event: UserCalendarEvent
    @State private var addsToExamOptionSchedules: Bool
    var universities: [UniversityChoice]
    var onSave: (UserCalendarEvent) -> Void

    init(
        draft: UserCalendarEvent,
        universities: [UniversityChoice],
        onSave: @escaping (UserCalendarEvent) -> Void
    ) {
        _event = State(initialValue: draft)
        _addsToExamOptionSchedules = State(initialValue: !draft.examOptionIDs.isEmpty)
        self.universities = universities
        self.onSave = onSave
    }

    private var selectedUniversity: UniversityChoice? {
        universities.first { $0.id == event.universityID }
    }

    private var trimmedTitle: String {
        event.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accentColor: Color {
        selectedUniversity?.color.color ?? .uniexamIndigo
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && (!addsToExamOptionSchedules || !event.examOptionIDs.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CalendarEventEditorSection(
                    title: "予定",
                    subtitle: "カレンダーに表示する名前",
                    systemImage: "text.cursor",
                    tint: accentColor
                ) {
                    TextField("予定名", text: $event.title)
                        .textInputAutocapitalization(.never)
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 13)
                        .frame(minHeight: 46)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 7))
                }

                CalendarEventEditorSection(
                    title: "日付",
                    subtitle: "予定を表示する日",
                    systemImage: "calendar",
                    tint: accentColor
                ) {
                    HStack {
                        Text(event.date.formatted(.monthDayWeekday))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        DatePicker(
                            "日付",
                            selection: $event.date,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }

                CalendarEventEditorSection(
                    title: "大学",
                    subtitle: "大学カレンダーにも自動で反映",
                    systemImage: "building.columns.fill",
                    tint: accentColor
                ) {
                    Menu {
                        Button("関連付けなし") {
                            event.universityID = nil
                        }
                        ForEach(universities) { university in
                            Button(university.name) {
                                event.universityID = university.id
                            }
                        }
                    } label: {
                        HStack(spacing: 11) {
                            Circle()
                                .fill(selectedUniversity?.color.color ?? Color.secondaryText.opacity(0.35))
                                .frame(width: 12, height: 12)
                            Text(selectedUniversity?.name ?? "関連付けなし")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.horizontal, 13)
                        .frame(minHeight: 46)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 7))
                    }
                    .onChange(of: event.universityID) { _, newUniversityID in
                        event.examOptionIDs = []
                        addsToExamOptionSchedules = false
                    }
                }

                if let selectedUniversity, !selectedUniversity.examOptions.isEmpty {
                    CalendarEventEditorSection(
                        title: "入試方式の日程",
                        subtitle: "登録済み情報にも同じ予定を追加",
                        systemImage: "doc.text.fill",
                        tint: selectedUniversity.color.color
                    ) {
                        Toggle("入試方式の日程にも追加", isOn: $addsToExamOptionSchedules)
                            .font(.body.weight(.semibold))
                            .tint(selectedUniversity.color.color)

                        if addsToExamOptionSchedules {
                            Divider()

                            Text("追加する方式を選択（複数可）")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondaryText)

                            ForEach(selectedUniversity.examOptions) { option in
                                Button {
                                    toggleOption(option.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: event.examOptionIDs.contains(option.id) ? "checkmark.square.fill" : "square")
                                            .font(.title2)
                                            .foregroundStyle(
                                                event.examOptionIDs.contains(option.id)
                                                    ? selectedUniversity.color.color
                                                    : Color.secondaryText
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.method.isEmpty ? "方式名未入力" : option.method)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(Color.primaryText)
                                            if !option.faculty.isEmpty {
                                                Text(option.faculty)
                                                    .font(.caption)
                                                    .foregroundStyle(Color.secondaryText)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(accentColor)
                    Text("大学を選ぶと大学別カレンダーにも表示されます。入試方式を選んだ場合は、各方式の「登録済み情報 > 日程」にも追加されます。")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .background(accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .navigationTitle("予定を追加")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                event.title = trimmedTitle
                event.date = Calendar.current.startOfDay(for: event.date)
                if !addsToExamOptionSchedules {
                    event.examOptionIDs = []
                }
                onSave(event)
            } label: {
                Label("予定を追加", systemImage: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSave ? accentColor : Color.secondaryText.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private func toggleOption(_ optionID: UUID) {
        if let index = event.examOptionIDs.firstIndex(of: optionID) {
            event.examOptionIDs.remove(at: index)
        } else {
            event.examOptionIDs.append(optionID)
        }
    }
}

struct CalendarEventEditorSection<Content: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            content
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CalendarDaySelection: Identifiable {
    let date: Date

    var id: Date { Calendar.current.startOfDay(for: date) }
}

struct CalendarDayAgendaSheet: View {
    @Environment(\.dismiss) private var dismiss
    var date: Date
    var events: [ExamEvent]
    var applicationRanges: [CalendarApplicationRange]
    var schools: [ExamSchool]
    var universities: [UniversityChoice] = []
    var onSave: ((UserCalendarEvent) -> Void)? = nil
    var onDelete: ((UUID) -> Void)? = nil

    @State private var addEventDraft: UserCalendarEvent?

    private var itemCount: Int {
        events.count + applicationRanges.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if itemCount == 0 {
                        ContentUnavailableView(
                            "予定はありません",
                            systemImage: "calendar",
                            description: Text(
                                onSave == nil
                                    ? "この日には登録された予定がありません。"
                                    : "右上の追加ボタンから予定を登録できます。"
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 34)
                    } else {
                        if !events.isEmpty && !applicationRanges.isEmpty {
                            CalendarAgendaSectionHeader(
                                title: "この日の予定",
                                systemImage: "calendar",
                                count: events.count
                            )
                        }

                        ForEach(events) { event in
                            CalendarEventRow(
                                event: event,
                                school: schools.first { $0.id == event.schoolID },
                                onDelete: onDelete == nil || event.kind != .custom
                                    ? nil
                                    : { onDelete?(event.id) }
                            )
                            if event.id != events.last?.id || !applicationRanges.isEmpty {
                                Divider().padding(.leading, 22)
                            }
                        }

                        if !applicationRanges.isEmpty {
                            CalendarAgendaSectionHeader(
                                title: "出願期間中",
                                systemImage: "arrow.left.and.right",
                                count: applicationRanges.count
                            )
                            .padding(.top, events.isEmpty ? 4 : 10)
                        }

                        ForEach(applicationRanges) { range in
                            ApplicationPeriodAgendaRow(range: range)
                            if range.id != applicationRanges.last?.id {
                                Divider().padding(.leading, 38)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationTitle(date.formatted(.monthDayWeekday))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if onSave != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            addEventDraft = UserCalendarEvent(
                                title: "",
                                date: Calendar.current.startOfDay(for: date)
                            )
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("予定を追加")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("\(itemCount)件")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.white)
            }
            .navigationDestination(item: $addEventDraft) { draft in
                AddCalendarEventSheet(draft: draft, universities: universities) { event in
                    onSave?(event)
                    addEventDraft = nil
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct CalendarAgendaSectionHeader: View {
    var title: String
    var systemImage: String
    var count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
            Text("\(count)件")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.secondaryText)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.secondaryText.opacity(0.075), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ApplicationPeriodAgendaRow: View {
    var range: CalendarApplicationRange

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(range.schoolColor.color.opacity(0.75))
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text([range.schoolName, range.faculty, range.optionName].filter { !$0.isEmpty }.joined(separator: "・"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Text("\(range.startDate.formatted(.shortMonthDay))〜\(range.endDate.formatted(.shortMonthDay))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.secondaryText)
                .monospacedDigit()
        }
        .padding(.vertical, 9)
    }
}

struct MonthGridView: View {
    var monthStart: Date
    @Binding var selectedDate: Date?
    var events: [ExamEvent]
    var applicationRanges: [CalendarApplicationRange]
    var showsUniversityNameInEvents = true
    var onOpenDate: (Date) -> Void
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
                        if let selectedDate, calendar.isDate(date, inSameDayAs: selectedDate) {
                            onOpenDate(date)
                        } else {
                            selectedDate = date
                        }
                    } label: {
                        CalendarDayCell(
                            date: date,
                            isCurrentMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                            isSelected: selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                            events: eventsForDay(date),
                            applicationRanges: applicationRangesForDay(date),
                            showsUniversityNameInEvents: showsUniversityNameInEvents
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } == true
                            ? "もう一度タップすると予定を表示します"
                            : "タップして選択します"
                    )
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

    private var hasExam: Bool {
        events.contains { $0.kind == .exam }
    }

    private var hasResult: Bool {
        events.contains { $0.kind == .result }
    }

    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: .demoToday)
    }

    private var eventHighlightColor: Color? {
        switch (hasExam, hasResult) {
        case (true, true):
            return Color.schoolPurple
        case (true, false):
            return Color.schoolSkyBlue
        case (false, true):
            return Color.schoolRosePink
        case (false, false):
            return nil
        }
    }

    @ViewBuilder
    private var cellBackground: some View {
        if hasExam && hasResult {
            LinearGradient(
                colors: [
                    Color.schoolSkyBlue.opacity(0.34),
                    Color.schoolRosePink.opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if let eventHighlightColor {
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.96), location: 0.28),
                    .init(color: eventHighlightColor.opacity(0.38), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isSelected {
            Color.uniexamIndigo.opacity(0.025)
        } else {
            Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color.uniexamIndigo.opacity(0.30)
        }

        if let eventHighlightColor {
            return eventHighlightColor.opacity(0.25)
        }

        if isToday {
            return Color.gray.opacity(0.48)
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
                    .foregroundStyle(isSelected ? Color.uniexamIndigo : (isCurrentMonth ? Color.primaryText : Color.secondaryText.opacity(0.45)))
                    .frame(minWidth: 27, minHeight: 24)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.uniexamIndigo.opacity(0.11))
                                .overlay {
                                    Capsule()
                                        .stroke(Color.uniexamIndigo.opacity(0.34), lineWidth: 0.8)
                                }
                        }
                    }
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
            if isToday {
                CalendarTodayHatch()
            }
            Rectangle()
                .stroke(borderColor, lineWidth: isSelected ? 1.2 : 0.7)
            if isSelected {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.uniexamIndigo.opacity(0.34), lineWidth: 0.9)
                    .padding(2.5)
            }
        }
    }
}

struct CalendarTodayHatch: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 6
            var offset = -size.height

            while offset < size.width {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(.gray.opacity(0.30)), lineWidth: 1)
                offset += spacing
            }
        }
        .background(Color.gray.opacity(0.09))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
    var onDelete: (() -> Void)? = nil

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
            if let onDelete {
                Menu {
                    Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 32, height: 40)
                }
                .accessibilityLabel("\(event.title)の操作")
            } else {
                Image(systemName: event.kind.icon)
                    .foregroundStyle(Color.secondaryText)
            }
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

                        ForEach(selectedUniversity.examOptions.filter { !$0.isHidden }) { option in
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
    var userDeviation: Double?
    var mockExamResults: [MockExamResult]
    @State private var selectedCategory: ExamOptionCategory = .general
    @State private var chartZoomScale = 1.0
    @State private var committedChartZoomScale = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(title: "戦略マップ")

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("入試方式", selection: $selectedCategory) {
                            ForEach([ExamOptionCategory.general, .commonTestOnly]) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("戦略マップの入試方式")

                        if selectedCategory == .general {
                            generalStrategyCard
                        } else {
                            commonTestStrategyCard
                        }
                    }
                    .padding(18)
                }
                .background(Color.appBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var generalStrategyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一般入試 レベル推移グラフ")
                .font(.headline)

            Text("グラフを2本指で広げたり縮めたりすると、偏差値の表示範囲を調整できます。")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            latestDeviationSummary

            Text("この偏差値や判定は最新の模試の結果を反映しています。模試の結果はサイドバーから追加・変更ができます。")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            if userDeviation != nil {
                HStack(spacing: 14) {
                    StrategyBandLegendItem(title: "安全校", color: .schoolAmber)
                    StrategyBandLegendItem(title: "相応校", color: .schoolMint)
                    StrategyBandLegendItem(title: "チャレンジ校", color: .schoolCoral)
                }
                .padding(.top, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                StrategyChart(
                    schools: generalSchools,
                    userDeviation: userDeviation,
                    yZoomScale: chartZoomScale,
                    mockExamResults: mockExamResults
                )
                    .frame(width: generalChartWidth, height: 660)
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
    }

    @ViewBuilder
    private var latestDeviationSummary: some View {
        if let userDeviation {
            Label {
                Text("最新模試の偏差値 \(userDeviation.formatted(.number.precision(.fractionLength(1))))")
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.uniexamIndigo)
            .padding(.top, 2)
        } else {
            Label("模試結果を登録すると基準ラインが表示されます", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .padding(.top, 2)
        }
    }

    private var commonTestStrategyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("共通テスト ボーダー得点率")
                .font(.headline)

            latestCommonTestScoreSummary
                .padding(.top, 2)

            Text("この得点率は最新の模試の結果を反映しています。模試の結果はサイドバーから追加・変更ができます。")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            if commonTestSchools.isEmpty {
                ContentUnavailableView(
                    "ボーダー得点率が未登録です",
                    systemImage: "chart.xyaxis.line",
                    description: Text("共テ単独方式の配点画面でボーダー得点率を入力すると表示されます。")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    CommonTestStrategyChart(
                        schools: commonTestSchools,
                        latestCommonTestScoreRate: latestCommonTestScoreRate
                    )
                        .frame(width: commonTestChartWidth, height: 480)
                        .padding(.trailing, 12)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var latestCommonTestScoreSummary: some View {
        if let latestCommonTestScoreRate {
            Label {
                Text("最新模試の得点率 \(latestCommonTestScoreRate.formatted(.number.precision(.fractionLength(0...1))))%")
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.uniexamIndigo)
        } else {
            Label("最新模試の得点率 未登録", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var generalSchools: [ExamSchool] {
        schools.filter { $0.resolvedAdmissionCategory == .general }
    }

    private var commonTestSchools: [ExamSchool] {
        schools
            .filter { school in
                guard school.resolvedAdmissionCategory == .commonTestOnly,
                      let rate = Double(percentageNumber(school.commonTestBorderRate)) else {
                    return false
                }
                return (50...100).contains(rate)
            }
            .sorted {
                if $0.name == $1.name {
                    return $0.method.localizedStandardCompare($1.method) == .orderedAscending
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var commonTestChartWidth: CGFloat {
        max(500, CGFloat(commonTestSchools.count) * 112 + 40)
    }

    private var latestCommonTestScoreRate: Double? {
        mockExamResults
            .filter { $0.isCommonTestMock && $0.commonTestScoreRate != nil }
            .max { $0.date < $1.date }?
            .commonTestScoreRate
    }

    private var generalTimelineRange: ClosedRange<Date>? {
        StrategyTimeline.range(for: generalSchools)
    }

    private var generalChartWidth: CGFloat {
        guard let range = generalTimelineRange else { return 860 }
        let days = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 0
        return max(860, CGFloat(days + 1) * 28 + 70)
    }

}

private enum StrategyTimeline {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func range(for schools: [ExamSchool]) -> ClosedRange<Date>? {
        let dates = schools.compactMap(\.examDate).map { calendar.startOfDay(for: $0) }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }

        var lowerBound = roundedDown(earliest)
        var upperBound = roundedUp(latest)

        // Round-number exam dates need a little breathing room so their labels
        // do not begin flush against the chart edge.
        if calendar.isDate(earliest, inSameDayAs: lowerBound) {
            lowerBound = calendar.date(byAdding: .day, value: -3, to: lowerBound) ?? lowerBound
        }
        if calendar.isDate(latest, inSameDayAs: upperBound) {
            upperBound = calendar.date(byAdding: .day, value: 3, to: upperBound) ?? upperBound
        }

        if lowerBound == upperBound {
            lowerBound = previousNiceDate(before: lowerBound) ?? calendar.date(byAdding: .day, value: -5, to: lowerBound) ?? lowerBound
            upperBound = nextNiceDate(after: upperBound) ?? calendar.date(byAdding: .day, value: 5, to: upperBound) ?? upperBound
        }

        return lowerBound...upperBound
    }

    static func ticks(in range: ClosedRange<Date>) -> [Date] {
        var values = [range.lowerBound, range.upperBound]
        var month = startOfMonth(containing: range.lowerBound)
        let finalMonth = startOfMonth(containing: range.upperBound)

        while month <= finalMonth {
            for day in [1, 5, 10, 15, 20, 25, 30] {
                guard let date = calendar.date(bySetting: .day, value: day, of: month),
                      calendar.component(.month, from: date) == calendar.component(.month, from: month),
                      range.contains(date) else {
                    continue
                }
                values.append(date)
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = nextMonth
        }

        return Array(Set(values)).sorted()
    }

    private static func roundedDown(_ date: Date) -> Date {
        let day = calendar.component(.day, from: date)
        let targetDay = [30, 25, 20, 15, 10, 5, 1].first(where: { $0 <= day }) ?? 1
        return calendar.date(bySetting: .day, value: targetDay, of: date).map { calendar.startOfDay(for: $0) } ?? date
    }

    private static func roundedUp(_ date: Date) -> Date {
        let day = calendar.component(.day, from: date)
        let monthDays = calendar.range(of: .day, in: .month, for: date)?.count ?? day
        let targetDay = ([1, 5, 10, 15, 20, 25, 30].first(where: { $0 >= day && $0 <= monthDays })) ?? monthDays
        return calendar.date(bySetting: .day, value: targetDay, of: date).map { calendar.startOfDay(for: $0) } ?? date
    }

    private static func previousNiceDate(before date: Date) -> Date? {
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) ?? date
        return niceDates(around: previousMonth, and: date).filter { $0 < date }.max()
    }

    private static func nextNiceDate(after date: Date) -> Date? {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        return niceDates(around: date, and: nextMonth).filter { $0 > date }.min()
    }

    private static func niceDates(around firstDate: Date, and secondDate: Date) -> [Date] {
        [firstDate, secondDate].flatMap { date in
            let monthStart = startOfMonth(containing: date)
            let monthDays = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
            let days = Array(Set([1, 5, 10, 15, 20, 25, 30, monthDays])).sorted()
            return days.compactMap { day -> Date? in
                guard day <= monthDays,
                      let value = calendar.date(bySetting: .day, value: day, of: monthStart),
                      calendar.component(.month, from: value) == calendar.component(.month, from: monthStart) else {
                    return nil
                }
                return calendar.startOfDay(for: value)
            }
        }
    }

    private static func startOfMonth(containing date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

private struct StrategyBandLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.48))
                .frame(width: 13, height: 13)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CommonTestStrategyChart: View {
    let schools: [ExamSchool]
    let latestCommonTestScoreRate: Double?

    private let minimumRate = 50.0
    private let maximumRate = 100.0
    private let yAxisValues = [50.0, 60.0, 70.0, 80.0, 90.0, 100.0]

    var body: some View {
        GeometryReader { proxy in
            let plot = CGRect(x: 44, y: 30, width: proxy.size.width - 62, height: proxy.size.height - 208)

            ZStack(alignment: .topLeading) {
                grid(in: plot)

                if let latestCommonTestScoreRate {
                    latestScoreRateLine(latestCommonTestScoreRate, in: plot)
                }

                ForEach(Array(schools.enumerated()), id: \.element.id) { index, school in
                    if let rate = borderRate(for: school) {
                        let x = xPosition(for: index, in: plot)
                        let y = yPosition(for: rate, in: plot)

                        Text("\(rate.formatted(.number.precision(.fractionLength(0...1))))%")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.primaryText)
                            .position(x: x, y: y - 17)

                        Circle()
                            .fill(school.color.color)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: school.color.color.opacity(0.3), radius: 3)
                            .position(x: x, y: y)
                            .accessibilityLabel("\(school.name)、\(school.method)、共通テストボーダー\(rate.formatted())パーセント")

                        verticalCategoryLabel(for: school)
                            .frame(width: 104, height: 162, alignment: .top)
                            .position(x: x, y: plot.maxY + 91)
                    }
                }
            }
        }
    }

    private func latestScoreRateLine(_ rate: Double, in plot: CGRect) -> some View {
        let y = yPosition(for: rate, in: plot)

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: plot.minX, y: y))
                path.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            .stroke(Color.uniexamIndigo.opacity(0.72), lineWidth: 2.5)

            HStack(spacing: 3) {
                Text("▶︎")
                    .font(.caption2.weight(.bold))
                Text(rate.formatted(.number.precision(.fractionLength(0...1))) + "%")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.uniexamIndigo)
            .position(x: plot.minX - 22, y: y)
        }
    }

    private func grid(in plot: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: plot.minX, y: plot.minY))
                path.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                path.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            }
            .stroke(Color.primaryText.opacity(0.7), lineWidth: 1)

            ForEach(yAxisValues, id: \.self) { rate in
                let y = yPosition(for: rate, in: plot)

                Path { path in
                    path.move(to: CGPoint(x: plot.minX, y: y))
                    path.addLine(to: CGPoint(x: plot.maxX, y: y))
                }
                .stroke(Color.secondaryText.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                Text("\(Int(rate))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Color.secondaryText)
                    .position(x: plot.minX - 21, y: y)
            }

            Text("得点率")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primaryText)
                .position(x: plot.minX + 8, y: plot.minY - 15)
        }
    }

    private func verticalCategoryLabel(for school: ExamSchool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verticalText(school.name))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.primaryText)
                .lineSpacing(1)

            Text(verticalText(school.method.isEmpty ? "方式未入力" : school.method))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(1)
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(school.color.color)
                .frame(width: 34, height: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(school.name)、\(school.method)")
    }

    private func verticalText(_ value: String) -> String {
        value.map(String.init).joined(separator: "\n")
    }

    private func borderRate(for school: ExamSchool) -> Double? {
        Double(percentageNumber(school.commonTestBorderRate))
    }

    private func xPosition(for index: Int, in plot: CGRect) -> CGFloat {
        guard schools.count > 1 else { return plot.midX }
        let horizontalInset = min(54.0, plot.width * 0.08)
        let availableWidth = plot.width - horizontalInset * 2
        return plot.minX + horizontalInset + availableWidth * CGFloat(index) / CGFloat(schools.count - 1)
    }

    private func yPosition(for rate: Double, in plot: CGRect) -> CGFloat {
        let clampedRate = min(max(rate, minimumRate), maximumRate)
        return plot.maxY - plot.height * CGFloat((clampedRate - minimumRate) / (maximumRate - minimumRate))
    }
}

struct StrategyChart: View {
    var schools: [ExamSchool]
    var userDeviation: Double?
    var yZoomScale: Double
    var mockExamResults: [MockExamResult]

    private var fullDeviationRange: ClosedRange<Double> {
        let deviations = schools.map(\.deviation)
        guard let minimum = deviations.min(), let maximum = deviations.max() else {
            return 30...75
        }
        return (minimum - 10)...(maximum + 10)
    }

    private var timelineRange: ClosedRange<Date> {
        if let range = StrategyTimeline.range(for: schools) {
            return range
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let start = calendar.date(from: DateComponents(year: year, month: 2, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: year, month: 2, day: 28)) ?? start
        return start...end
    }

    private var visibleDeviationRange: ClosedRange<Double> {
        let fullRange = fullDeviationRange
        let fullSpan = fullRange.upperBound - fullRange.lowerBound
        let visibleSpan = fullSpan / min(max(yZoomScale, 1.0), 3.5)
        let halfSpan = visibleSpan / 2
        let requestedCenter = userDeviation ?? (fullRange.lowerBound + fullRange.upperBound) / 2
        let center = min(max(requestedCenter, fullRange.lowerBound + halfSpan), fullRange.upperBound - halfSpan)
        return (center - halfSpan)...(center + halfSpan)
    }

    var body: some View {
        GeometryReader { proxy in
            let plot = CGRect(x: 62, y: 20, width: proxy.size.width - 84, height: proxy.size.height - 310)

            ZStack(alignment: .topLeading) {
                if let userDeviation {
                    schoolLevelBands(for: userDeviation, in: plot)
                }
                grid(in: plot)
                schoolTrendLine(in: plot)
                if let userDeviation {
                    userDeviationLine(for: userDeviation, in: plot)
                }

                ForEach(visibleExamSchools) { school in
                    if let date = school.examDate {
                        Circle()
                            .fill(school.color.color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: school.color.color.opacity(0.25), radius: 2)
                            .position(
                                x: xPosition(for: date, in: plot),
                                y: yPosition(for: school.deviation, in: plot)
                            )
                            .accessibilityLabel("\(date.formatted(.shortMonthDay))、\(school.name)、偏差値\(school.deviationText)")
                    }
                }

                verticalExamLabels(in: plot)
            }
        }
    }

    private var examSchools: [ExamSchool] {
        schools
            .filter { $0.examDate != nil }
            .sorted {
                if $0.examDate == $1.examDate {
                    return $0.deviation < $1.deviation
                }
                return ($0.examDate ?? .distantFuture) < ($1.examDate ?? .distantFuture)
            }
    }

    private var visibleExamSchools: [ExamSchool] {
        examSchools.filter { visibleDeviationRange.contains($0.deviation) }
    }

    @ViewBuilder
    private func schoolTrendLine(in plot: CGRect) -> some View {
        if visibleExamSchools.count > 1 {
            Path { path in
                for (index, school) in visibleExamSchools.enumerated() {
                    guard let date = school.examDate else { continue }
                    let point = CGPoint(
                        x: xPosition(for: date, in: plot),
                        y: yPosition(for: school.deviation, in: plot)
                    )
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(
                Color.schoolSlate.opacity(0.72),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func verticalExamLabels(in plot: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(examLabelDates, id: \.self) { date in
                let dateSchools = visibleExamSchools.filter {
                    guard let examDate = $0.examDate else { return false }
                    return Calendar.current.isDate(examDate, inSameDayAs: date)
                }
                let pointX = xPosition(for: date, in: plot)
                let columnWidth = max(100, CGFloat(dateSchools.count) * 80)

                Path { path in
                    path.move(to: CGPoint(x: pointX, y: plot.maxY))
                    path.addLine(to: CGPoint(x: pointX, y: plot.maxY + 8))
                }
                .stroke(Color.secondaryText.opacity(0.28), lineWidth: 1)

                VStack(spacing: 7) {
                    Text(date.formatted(.shortMonthDay))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.primaryText)

                    HStack(spacing: 10) {
                        ForEach(dateSchools) { school in
                            latestJudgmentBadge(for: school)
                                .frame(width: 70)
                        }
                    }

                    HStack(spacing: 10) {
                        ForEach(dateSchools) { school in
                            Rectangle()
                                .fill(school.color.color.opacity(0.78))
                                .frame(
                                    width: shouldShowFullMethod(for: school) ? 52 : 28,
                                    height: 2
                                )
                                .frame(width: 70)
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        ForEach(dateSchools) { school in
                            verticalSchoolLabel(school)
                                .frame(width: 70, alignment: .top)
                        }
                    }
                }
                .frame(width: columnWidth, height: 250, alignment: .top)
                .position(x: pointX, y: plot.maxY + 161)
            }
        }
    }

    private func latestJudgmentBadge(for school: ExamSchool) -> some View {
        let grade = latestJudgment(for: school)
        let color = grade?.strategyColor ?? Color.schoolSlate
        let title = grade?.shortStrategyLabel ?? "−"

        return Text(title)
            .font(.title3.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: 64, height: 32)
            .accessibilityLabel(grade?.rawValue ?? "判定なし")
    }

    private func latestJudgment(for school: ExamSchool) -> MockExamJudgmentGrade? {
        mockExamResults.compactMap { result -> (date: Date, grade: MockExamJudgmentGrade)? in
            guard let judgment = result.judgments.first(where: { $0.examOptionID == school.id }) else {
                return nil
            }
            return (result.date, judgment.grade)
        }
        .max { $0.date < $1.date }?
        .grade
    }

    private var examLabelDates: [Date] {
        let dates = visibleExamSchools.compactMap(\.examDate).map { Calendar.current.startOfDay(for: $0) }
        return Array(Set(dates)).sorted()
    }

    private func verticalSchoolLabel(_ school: ExamSchool) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .top, spacing: 5) {
                Text(verticalText(school.name))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.primaryText)

                if shouldShowFullMethod(for: school) {
                    Text(verticalText(fullExamOptionName(for: school)))
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .lineSpacing(0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(school.name)、\(school.method)")
    }

    private func shouldShowFullMethod(for school: ExamSchool) -> Bool {
        examSchools.filter { $0.name == school.name }.count > 1
    }

    private func fullExamOptionName(for school: ExamSchool) -> String {
        let value = [school.faculty, school.method]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "・")
        return value.isEmpty ? "方式未入力" : value
    }

    private func verticalText(_ value: String) -> String {
        value.map(String.init).joined(separator: "\n")
    }

    private func xPosition(for date: Date, in plot: CGRect) -> CGFloat {
        let calendar = Calendar.current
        let start = timelineRange.lowerBound
        let end = timelineRange.upperBound
        let normalizedDate = calendar.startOfDay(for: date)
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
        let elapsedDays = calendar.dateComponents([.day], from: start, to: normalizedDate).day ?? 0
        let progress = min(max(Double(elapsedDays) / Double(totalDays), 0), 1)
        return plot.minX + plot.width * CGFloat(progress)
    }

    private func userDeviationLine(for userDeviation: Double, in plot: CGRect) -> some View {
        let y = yPosition(for: userDeviation, in: plot)

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: plot.minX, y: y))
                path.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
            .stroke(Color.uniexamIndigo.opacity(0.82), lineWidth: 2.5)

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

    private func schoolLevelBands(for userDeviation: Double, in plot: CGRect) -> some View {
        let safeBottom = userDeviation - 7.5
        let safeTop = userDeviation - 2.5
        let matchBottom = userDeviation - 2.5
        let matchTop = userDeviation + 2.5
        let challengeBottom = userDeviation + 2.5
        let challengeTop = userDeviation + 7.5

        return ZStack(alignment: .topLeading) {
            band(from: safeBottom, to: safeTop, color: .schoolAmber, in: plot)
            band(from: matchBottom, to: matchTop, color: .schoolMint, in: plot)
            band(from: challengeBottom, to: challengeTop, color: .schoolCoral, in: plot)
        }
    }

    @ViewBuilder
    private func band(from lower: Double, to upper: Double, color: Color, in plot: CGRect) -> some View {
        let range = visibleDeviationRange
        let clampedLower = min(max(lower, range.lowerBound), range.upperBound)
        let clampedUpper = min(max(upper, range.lowerBound), range.upperBound)

        if clampedUpper > clampedLower {
            let yTop = yPosition(for: clampedUpper, in: plot)
            let yBottom = yPosition(for: clampedLower, in: plot)
            let bandHeight = max(yBottom - yTop, 0)
            Rectangle()
                .fill(color.opacity(0.22))
                .frame(width: plot.width, height: bandHeight)
                .position(x: plot.midX, y: yTop + bandHeight / 2)
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

            ForEach(StrategyTimeline.ticks(in: timelineRange), id: \.self) { date in
                let x = xPosition(for: date, in: plot)
                Path { path in
                    path.move(to: CGPoint(x: x, y: plot.minY))
                    path.addLine(to: CGPoint(x: x, y: plot.maxY))
                }
                .stroke(Color.secondaryText.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                Text(date.formatted(.shortMonthDay))
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
        String(format: "%.1f", value)
    }
}

private extension MockExamJudgmentGrade {
    var shortStrategyLabel: String {
        String(rawValue.prefix(1))
    }

    var strategyColor: Color {
        switch self {
        case .a: .schoolBrightRed
        case .b: .schoolAmber
        case .c: .schoolLimeGreen
        case .d: .schoolPurple
        case .f: .schoolSlate
        }
    }

    var usesDarkStrategyText: Bool {
        self == .b || self == .c
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

enum UserCalendarEventPersistence {
    private static let key = "uniexam.calendarEvents.v1"

    static func load() -> [UserCalendarEvent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([UserCalendarEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func save(_ events: [UserCalendarEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: key)
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
        NotificationCenter.default.post(name: .uniexamCustomColorsDidChange, object: nil)
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

    static func applicationPeriodText(start: Date?, end: Date?, includeYear: Bool = false) -> String {
        let format: Date.FormatStyle = includeYear ? .examDate : .shortMonthDay
        return switch (start, end) {
        case let (start?, end?):
            "\(start.formatted(format))〜\(end.formatted(format))"
        case let (start?, nil):
            "\(start.formatted(format))〜未設定"
        case let (nil, end?):
            "未設定〜\(end.formatted(format))"
        default:
            ""
        }
    }

    var countdownText: String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: self)
        guard let days = calendar.dateComponents([.day], from: today, to: target).day,
              (0...10).contains(days) else { return nil }
        return days == 0 ? "今日" : "あと\(days)日"
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
