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
        appendDate("出願開始", applicationStart, "doc.text", &items)
        appendDate("出願締切", applicationEnd, "doc.text.fill", &items)
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
    var id = UUID()
    var title: String
    var value: String
    var systemImage: String
}

struct ExamEvent: Identifiable, Hashable {
    var id = UUID()
    var schoolID: UUID
    var schoolName: String
    var schoolColor: SchoolColor
    var kind: EventKind
    var date: Date?
    var title: String
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
}

enum SchoolColor: String, CaseIterable, Identifiable, Codable {
    case blue
    case coral
    case teal
    case violet
    case amber
    case mint

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .schoolBlue
        case .coral: .schoolCoral
        case .teal: .schoolTeal
        case .violet: .schoolViolet
        case .amber: .schoolAmber
        case .mint: .schoolMint
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
        .padding(.top, 12)
        .padding(.bottom, 14)
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
                AppTopBar(title: "志望校", subtitle: "一覧", trailingSystemImage: "plus", trailingAction: {
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
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 14) {
                            SchoolMonogram(school: school)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(school.name)
                                    .font(.title2.weight(.bold))
                                Text("\(school.faculty.isEmpty ? "学部未入力" : school.faculty) / \(school.method)")
                                    .foregroundStyle(Color.secondaryText)
                                Text("偏差値 \(school.deviationText)")
                                    .font(.headline)
                                    .foregroundStyle(school.color.color)
                            }
                            Spacer()
                        }
                    }
                    .padding(18)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("登録済み情報")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                        ForEach(school.filledDetailItems) { item in
                            DetailInfoRow(item: item, tint: school.color.color)
                            if item.id != school.filledDetailItems.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }

                        if school.filledDetailItems.isEmpty {
                            Text("任意項目はまだ入力されていません。")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                                .padding(16)
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(18)
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
}

struct DetailInfoRow: View {
    var item: DetailItem
    var tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                Text(item.value)
                    .font(.subheadline)
                    .foregroundStyle(Color.primaryText)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct EditSchoolView: View {
    enum Mode {
        case add
        case edit
    }

    @Environment(\.dismiss) private var dismiss
    var mode: Mode
    @State var school: ExamSchool
    var onSave: (ExamSchool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("必須") {
                    TextField("学校名", text: $school.name)
                    TextField("方式", text: $school.method)
                    HStack {
                        Text("偏差値")
                        Slider(value: $school.deviation, in: 35...80, step: 0.5)
                        Text(school.deviation, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                Section("基本情報") {
                    TextField("学部・学科", text: $school.faculty)
                    Picker("大学カラー", selection: $school.color) {
                        ForEach(SchoolColor.allCases) { color in
                            Text(color.rawValue.capitalized)
                                .tag(color)
                        }
                    }
                }

                DisclosureGroup("日程") {
                    OptionalDatePicker(title: "入試日程", date: $school.examDate)
                    OptionalDatePicker(title: "出願開始", date: $school.applicationStart)
                    OptionalDatePicker(title: "出願締切", date: $school.applicationEnd)
                    OptionalDatePicker(title: "入金締切", date: $school.paymentDeadline)
                    OptionalDatePicker(title: "合格発表日", date: $school.resultDate)
                    OptionalDatePicker(title: "入学金締切", date: $school.admissionFeeDeadline)
                    OptionalDatePicker(title: "授業料締切", date: $school.tuitionDeadline)
                }

                DisclosureGroup("出願情報") {
                    TextField("出願に必要な書類", text: $school.requiredDocuments, axis: .vertical)
                    TextField("募集要項URL", text: $school.guidelineURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("パスナビURL", text: $school.passnaviURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("出願サイトURL", text: $school.applicationURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                DisclosureGroup("試験情報") {
                    SubjectEditor(subjects: $school.subjects)
                    TextField("合格者最低点", text: $school.minimumPassingScore)
                    TextField("倍率", text: $school.acceptanceRatio)
                    TextField("募集人数", text: $school.capacity)
                }

                DisclosureGroup("その他") {
                    TextField("メモ", text: $school.memo, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
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
                    .disabled(school.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || school.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct OptionalDatePicker: View {
    var title: String
    @Binding var date: Date?

    var body: some View {
        Toggle(isOn: Binding(
            get: { date != nil },
            set: { isOn in date = isOn ? (date ?? .demoToday) : nil }
        )) {
            Text(title)
        }

        if let unwrappedDate = date {
            DatePicker(
                "",
                selection: Binding(
                    get: { unwrappedDate },
                    set: { date = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
        }
    }
}

struct SubjectEditor: View {
    @Binding var subjects: [SubjectScore]
    @State private var newSubject = ""
    @State private var newScore = ""

    var body: some View {
        ForEach($subjects) { $subject in
            HStack {
                TextField("科目", text: $subject.subject)
                TextField("配点", text: $subject.score)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .onDelete { subjects.remove(atOffsets: $0) }

        HStack {
            TextField("科目を追加", text: $newSubject)
            TextField("配点", text: $newScore)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
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

struct ExamCalendarView: View {
    var schools: [ExamSchool]
    @State private var selectedDate = Date.from(year: 2027, month: 2, day: 6)
    @State private var selectedKind: EventKind = .all
    @State private var selectedSchoolID: UUID?

    private let calendar = Calendar.current
    private let monthStart = Date.from(year: 2027, month: 2, day: 1)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(title: "カレンダー", subtitle: "2027年2月", trailingSystemImage: "line.3.horizontal.decrease.circle")

                filterBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MonthGridView(
                            monthStart: monthStart,
                            selectedDate: $selectedDate,
                            events: filteredEvents
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
                    .padding(18)
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

    private func events(on date: Date) -> [ExamEvent] {
        filteredEvents
            .filter { event in
                guard let eventDate = event.date else { return false }
                return calendar.isDate(eventDate, inSameDayAs: date)
            }
            .sorted { $0.title < $1.title }
    }
}

struct MonthGridView: View {
    var monthStart: Date
    @Binding var selectedDate: Date
    var events: [ExamEvent]

    private let calendar = Calendar.current
    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {} label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(true)

                Spacer()
                Text("2027年2月")
                    .font(.title2.weight(.bold))
                Spacer()

                Button {} label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(true)
            }

            LazyVGrid(columns: columns, spacing: 10) {
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
                            isCurrentMonth: calendar.component(.month, from: date) == 2,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            events: eventsForDay(date)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var calendarDates: [Date] {
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let mondayBasedOffset = (firstWeekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayBasedOffset, to: monthStart) ?? monthStart
        return (0..<35).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func eventsForDay(_ date: Date) -> [ExamEvent] {
        events.filter { event in
            guard let eventDate = event.date else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }
}

struct CalendarDayCell: View {
    var date: Date
    var isCurrentMonth: Bool
    var isSelected: Bool
    var events: [ExamEvent]

    var body: some View {
        VStack(spacing: 5) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.body.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : (isCurrentMonth ? .primaryText : .secondaryText.opacity(0.45)))
                .frame(width: 34, height: 34)
                .background(isSelected ? Color.uniexamIndigo : Color.clear, in: Circle())

            HStack(spacing: 3) {
                ForEach(events.prefix(3)) { event in
                    Circle()
                        .fill(event.schoolColor.color)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 48)
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
    static let deepNavy = Color(red: 0.12, green: 0.23, blue: 0.37)
    static let uniexamIndigo = Color(red: 0.28, green: 0.34, blue: 0.78)
    static let clearBlue = Color(red: 0.44, green: 0.65, blue: 0.91)
    static let appBackground = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let primaryText = Color(red: 0.19, green: 0.22, blue: 0.28)
    static let secondaryText = Color(red: 0.48, green: 0.52, blue: 0.58)
    static let schoolBlue = Color(red: 0.35, green: 0.55, blue: 0.94)
    static let schoolCoral = Color(red: 0.95, green: 0.43, blue: 0.52)
    static let schoolTeal = Color(red: 0.30, green: 0.65, blue: 0.66)
    static let schoolViolet = Color(red: 0.55, green: 0.47, blue: 0.80)
    static let schoolAmber = Color(red: 0.86, green: 0.66, blue: 0.28)
    static let schoolMint = Color(red: 0.48, green: 0.75, blue: 0.55)
}

extension Date {
    static let demoToday = Date.from(year: 2027, month: 1, day: 10)

    static func from(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
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
}

#Preview {
    ContentView()
}
