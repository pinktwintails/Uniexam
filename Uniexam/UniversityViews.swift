import SwiftUI

enum SchoolListMode: String, CaseIterable, Identifiable {
    case university = "大学別"
    case examOption = "入試方式別"

    var id: String { rawValue }
}

enum ExamOptionCategoryFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case commonTestOnly = "共テ単独"
    case general = "一般"

    var id: String { rawValue }

    func includes(_ category: ExamOptionCategory) -> Bool {
        switch self {
        case .all: true
        case .commonTestOnly: category == .commonTestOnly
        case .general: category == .general
        }
    }
}

extension ExamOptionCategory {
    var listTint: Color {
        switch self {
        case .general: .schoolBlue
        case .commonTestOnly: .schoolBrightRed
        }
    }
}

struct UniversityListView: View {
    @Binding var universities: [UniversityChoice]
    var listMode: SchoolListMode
    @State private var showingAddFlow = false
    @AppStorage("universityListSortOption") private var universitySortOption = SchoolSortOption.alphabetical
    @AppStorage("examOptionListSortOption") private var optionSortOption = SchoolSortOption.examDate
    @AppStorage("examOptionCategoryFilter") private var categoryFilter = ExamOptionCategoryFilter.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppTopBar(
                    title: listMode == .university ? "志望校" : "入試方式",
                    trailingSystemImage: "plus",
                    trailingAction: showAddFlow
                )

                if listMode == .examOption {
                    Picker("入試方式の区分", selection: $categoryFilter) {
                        ForEach(ExamOptionCategoryFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(.white)
                }

                listToolbar

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if listMode == .university {
                            ForEach(sortedUniversities) { university in
                                NavigationLink {
                                    UniversityDetailView(
                                        university: universityBinding(for: university.id)
                                    )
                                } label: {
                                    UniversityRow(university: university)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            ForEach(visibleExamOptions) { school in
                                NavigationLink {
                                    SchoolDetailView(
                                        school: optionBinding(for: school),
                                        fixedUniversity: universities.first { $0.id == school.universityID }
                                    )
                                } label: {
                                    ExamOptionListRow(school: school)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if listMode == .university && universities.isEmpty {
                            ContentUnavailableView(
                                "志望校がまだありません",
                                systemImage: "building.columns",
                                description: Text("右上の追加ボタンから大学のみ、または大学と入試方式を登録できます。")
                            )
                            .padding(.top, 72)
                        } else if listMode == .examOption && visibleExamOptions.isEmpty {
                            ContentUnavailableView(
                                categoryFilter == .all ? "入試方式がまだありません" : "\(categoryFilter.rawValue)の方式はありません",
                                systemImage: "doc.text",
                                description: Text(categoryFilter == .all ? "右上の追加ボタンから既存大学への方式追加、または大学と方式の登録ができます。" : "方式の編集画面で区分を変更できます。")
                            )
                            .padding(.top, 72)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .background(Color.appBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddFlow) {
                SchoolAddMenu(
                    universities: $universities,
                    nextColor: SchoolColor.allCases[universities.count % SchoolColor.allCases.count]
                )
            }
        }
    }

    private var listToolbar: some View {
        HStack(spacing: 12) {
            Text(listMode == .university ? "\(universities.count)校" : "\(visibleExamOptions.count)方式")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
            Spacer()
            Menu {
                Picker("並び替え", selection: activeSortBinding) {
                    ForEach(SchoolSortOption.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Label(activeSortOption.title, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.uniexamIndigo)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Color.uniexamIndigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            }
            .accessibilityLabel(listMode == .university ? "志望校を並び替え" : "入試方式を並び替え")
            .accessibilityValue(activeSortOption.title)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.white)
    }

    private var activeSortOption: SchoolSortOption {
        listMode == .university ? universitySortOption : optionSortOption
    }

    private var activeSortBinding: Binding<SchoolSortOption> {
        Binding(
            get: { activeSortOption },
            set: { newValue in
                if listMode == .university {
                    universitySortOption = newValue
                } else {
                    optionSortOption = newValue
                }
            }
        )
    }

    private var sortedUniversities: [UniversityChoice] {
        universities.sorted { lhs, rhs in
            switch universitySortOption {
            case .alphabetical:
                universityAlphabeticallyPrecedes(lhs, rhs)
            case .deviation:
                lhs.maximumDeviation == rhs.maximumDeviation
                    ? universityAlphabeticallyPrecedes(lhs, rhs)
                    : lhs.maximumDeviation > rhs.maximumDeviation
            case .examDate:
                datePrecedes(lhs.earliestExamDate, rhs.earliestExamDate) {
                    universityAlphabeticallyPrecedes(lhs, rhs)
                }
            case .nearestEvent:
                datePrecedes(lhs.nextEvent?.date, rhs.nextEvent?.date) {
                    universityAlphabeticallyPrecedes(lhs, rhs)
                }
            }
        }
    }

    private var sortedJoinedSchools: [ExamSchool] {
        universities.flatMap(\.joinedSchools).sorted { lhs, rhs in
            switch optionSortOption {
            case .alphabetical:
                optionAlphabeticallyPrecedes(lhs, rhs)
            case .deviation:
                lhs.deviation == rhs.deviation
                    ? optionAlphabeticallyPrecedes(lhs, rhs)
                    : lhs.deviation > rhs.deviation
            case .examDate:
                datePrecedes(lhs.examDate, rhs.examDate) { optionAlphabeticallyPrecedes(lhs, rhs) }
            case .nearestEvent:
                datePrecedes(nextEventDate(for: lhs), nextEventDate(for: rhs)) {
                    optionAlphabeticallyPrecedes(lhs, rhs)
                }
            }
        }
    }

    private var visibleExamOptions: [ExamSchool] {
        sortedJoinedSchools.filter { categoryFilter.includes($0.resolvedAdmissionCategory) }
    }

    private func universityAlphabeticallyPrecedes(_ lhs: UniversityChoice, _ rhs: UniversityChoice) -> Bool {
        sortName(for: lhs).localizedStandardCompare(sortName(for: rhs)) == .orderedAscending
    }

    private func optionAlphabeticallyPrecedes(_ lhs: ExamSchool, _ rhs: ExamSchool) -> Bool {
        let lhsName = [lhs.nameKana.isEmpty ? lhs.name : lhs.nameKana, lhs.faculty, lhs.method].joined(separator: "|")
        let rhsName = [rhs.nameKana.isEmpty ? rhs.name : rhs.nameKana, rhs.faculty, rhs.method].joined(separator: "|")
        if lhsName.localizedStandardCompare(rhsName) == .orderedSame {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
    }

    private func sortName(for university: UniversityChoice) -> String {
        university.nameKana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? university.name
            : university.nameKana
    }

    private func datePrecedes(_ lhs: Date?, _ rhs: Date?, tieBreaker: () -> Bool) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return lhs == rhs ? tieBreaker() : lhs < rhs
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return tieBreaker()
        }
    }

    private func nextEventDate(for school: ExamSchool) -> Date? {
        school.events.compactMap(\.date).filter { $0 >= .demoToday }.min()
    }

    private func showAddFlow() {
        showingAddFlow = true
    }

    private func universityBinding(for id: UUID) -> Binding<UniversityChoice> {
        Binding(
            get: { universities.first(where: { $0.id == id }) ?? .blank() },
            set: { updated in
                guard let index = universities.firstIndex(where: { $0.id == id }) else { return }
                universities[index] = updated
            }
        )
    }

    private func optionBinding(for school: ExamSchool) -> Binding<ExamSchool> {
        Binding(
            get: {
                guard let universityIndex = universities.firstIndex(where: { $0.id == school.universityID }),
                      let option = universities[universityIndex].examOptions.first(where: { $0.id == school.id }) else {
                    return school
                }
                return option.joined(with: universities[universityIndex])
            },
            set: { updated in
                guard let universityIndex = universities.firstIndex(where: { $0.id == school.universityID }),
                      let optionIndex = universities[universityIndex].examOptions.firstIndex(where: { $0.id == school.id }) else {
                    return
                }
                universities[universityIndex].name = updated.name
                universities[universityIndex].nameKana = updated.nameKana
                universities[universityIndex].universityType = updated.universityType
                universities[universityIndex].color = updated.color
                universities[universityIndex].passnaviURL = updated.passnaviURL
                universities[universityIndex].examOptions[optionIndex].update(from: updated)
            }
        )
    }
}

struct UniversityRow: View {
    var university: UniversityChoice

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String(university.name.prefix(1)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(university.color.color, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(university.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        if university.preferenceRank != nil {
                            PreferenceRankBadge(university: university)
                        }
                    }

                    HStack(spacing: 7) {
                        Text(university.universityType.displayName)
                            .foregroundStyle(Color.primaryText)
                        Text("・")
                            .foregroundStyle(Color.secondaryText)
                        Text("\(university.examOptions.count)方式")
                            .foregroundStyle(Color.primaryText)
                    }
                    .font(.callout.weight(.medium))

                    HStack(spacing: 6) {
                        Text("偏差値")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.secondaryText)
                        Text(university.deviationRangeText)
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(university.color.color)
                    }
                }
                .layoutPriority(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(16)

            Divider().padding(.leading, 16)

            if university.examOptions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(Color.secondaryText)
                    Text("入試方式未登録")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedOptions.enumerated()), id: \.element.id) { index, option in
                        UniversityOptionCompactRow(option: option)
                        if index < sortedOptions.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .background(university.color.color.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle().fill(university.color.color.opacity(0.8)).frame(width: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(university.color.color.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(university.name)、\(university.preferenceRankText)、\(university.examOptions.count)方式、偏差値\(university.deviationRangeText)、\(optionAccessibilitySummary)")
    }

    private var optionAccessibilitySummary: String {
        guard !university.examOptions.isEmpty else { return "入試方式未登録" }
        return sortedOptions
            .map { "\($0.resolvedAdmissionCategory.rawValue)、\($0.title.isEmpty ? "名称未入力" : $0.title)" }
            .joined(separator: "、")
    }

    private var sortedOptions: [ExamOption] {
        university.examOptions.sorted { lhs, rhs in
            let lhsIsCommon = lhs.resolvedAdmissionCategory == .commonTestOnly
            let rhsIsCommon = rhs.resolvedAdmissionCategory == .commonTestOnly
            if lhsIsCommon != rhsIsCommon {
                return lhsIsCommon
            }

            switch (lhs.examDate, rhs.examDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate == rhsDate
                    ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    : lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

struct UniversityOptionCompactRow: View {
    var option: ExamOption

    private var isCommonTestOnly: Bool {
        option.resolvedAdmissionCategory == .commonTestOnly
    }

    private var tint: Color {
        option.resolvedAdmissionCategory.listTint
    }

    var body: some View {
        HStack(spacing: 9) {
            Text(option.resolvedAdmissionCategory.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 4) {
                Text(option.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "方式名未入力" : option.method)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.primaryText)

                if !option.faculty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("・\(option.faculty)")
                        .font(.callout)
                        .foregroundStyle(Color.primaryText.opacity(0.68))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .layoutPriority(1)

            Spacer(minLength: 6)

            if !isCommonTestOnly, let examDate = option.examDate {
                Text(examDate.formatted(.shortMonthDay))
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(tint.opacity(0.24), lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

struct ExamOptionListRow: View {
    var school: ExamSchool

    private var categoryTint: Color {
        school.resolvedAdmissionCategory.listTint
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: school.resolvedAdmissionCategory == .commonTestOnly ? "checklist" : "doc.text.fill")
                    .font(.headline)
                    .foregroundStyle(categoryTint)
                    .frame(width: 40, height: 40)
                    .background(categoryTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(school.color.color)
                        Text(school.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(school.color.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)

                        Text("・")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.secondaryText)

                        Text(school.faculty.isEmpty ? "学部未入力" : school.faculty)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)
                    }

                    HStack(spacing: 7) {
                        Text(school.resolvedAdmissionCategory.rawValue)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(categoryTint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(categoryTint.opacity(0.11), in: RoundedRectangle(cornerRadius: 4))

                        Text(school.method.isEmpty ? "方式名未入力" : school.method)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("偏差値")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    Text(school.deviationText)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(school.color.color)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondaryText)
                    .padding(.top, 12)
            }
            .padding(14)

            Divider()
                .padding(.leading, 66)

            HStack(spacing: 8) {
                Image(systemName: nextEvent?.kind.icon ?? "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(school.color.color)
                Text(nextEvent?.title ?? "次の予定なし")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Text(nextEvent?.date?.formatted(.monthDayWeekday) ?? "-")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(school.color.color.opacity(0.07))
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(school.color.color)
                .frame(width: 4)
        }
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(school.name)、\(school.resolvedAdmissionCategory.rawValue)、\(school.faculty)、\(school.method)、偏差値\(school.deviationText)")
    }

    private var nextEvent: ExamEvent? {
        school.events
            .filter { ($0.date ?? .distantPast) >= .demoToday }
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }
}

struct UniversityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var university: UniversityChoice

    @State private var showingUniversityEditor = false
    @State private var showingOptionEditor = false
    @State private var optionPendingDeletion: ExamOption?

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "大学詳細",
                subtitle: university.name,
                leadingSystemImage: "chevron.left",
                trailingSystemImage: "square.and.pencil",
                leadingAction: { dismiss() },
                trailingAction: { showingUniversityEditor = true }
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    UniversitySummaryCard(university: university)

                    HStack {
                        Text("入試方式")
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text("\(university.examOptions.count)件")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)
                        Button { showingOptionEditor = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(university.color.color)
                        }
                        .accessibilityLabel("入試方式を追加")
                    }

                    ForEach(university.examOptions) { option in
                        HStack(spacing: 8) {
                            NavigationLink {
                                SchoolDetailView(school: optionBinding(for: option.id), fixedUniversity: university)
                            } label: {
                                ExamOptionRow(option: option, color: university.color.color)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button { duplicate(option) } label: {
                                    Label("複製", systemImage: "plus.square.on.square")
                                }
                                Button(role: .destructive) { optionPendingDeletion = option } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .accessibilityLabel("\(option.title)の操作")
                        }
                    }

                    UniversityScheduleCalendar(university: university)
                }
                .padding(16)
            }
            .background(Color.appBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingUniversityEditor) {
            UniversityEditorView(university: university) { university = $0 }
        }
        .sheet(isPresented: $showingOptionEditor) {
            EditSchoolView(mode: .add, school: ExamOption.blank.joined(with: university), fixedUniversity: university) { school in
                university.examOptions.append(ExamOption(legacy: school))
            }
        }
        .confirmationDialog(
            "この入試方式を削除しますか？",
            isPresented: Binding(
                get: { optionPendingDeletion != nil },
                set: { if !$0 { optionPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let optionPendingDeletion {
                    university.examOptions.removeAll { $0.id == optionPendingDeletion.id }
                }
                optionPendingDeletion = nil
            }
        }
    }

    private func duplicate(_ option: ExamOption) {
        var copy = option
        copy.id = UUID()
        copy.method = option.method.isEmpty ? "コピー" : "\(option.method) コピー"
        university.examOptions.append(copy)
    }

    private func optionBinding(for id: UUID) -> Binding<ExamSchool> {
        Binding(
            get: {
                guard let option = university.examOptions.first(where: { $0.id == id }) else {
                    return ExamOption.blank.joined(with: university)
                }
                return option.joined(with: university)
            },
            set: { updated in
                guard let index = university.examOptions.firstIndex(where: { $0.id == id }) else { return }
                university.name = updated.name
                university.nameKana = updated.nameKana
                university.universityType = updated.universityType
                university.color = updated.color
                university.passnaviURL = updated.passnaviURL
                university.examOptions[index].update(from: updated)
            }
        )
    }
}

struct UniversityScheduleCalendar: View {
    var university: UniversityChoice
    @State private var selectedDate: Date
    @State private var displayedMonth: Date

    private let calendar = Calendar.current

    init(university: UniversityChoice) {
        self.university = university
        let initialDate = university.joinedSchools
            .flatMap(\.events)
            .compactMap(\.date)
            .filter { $0 >= .demoToday }
            .min()
            ?? university.joinedSchools.flatMap(\.events).compactMap(\.date).min()
            ?? Date.from(year: 2027, month: 2, day: 1)
        _selectedDate = State(initialValue: initialDate)
        _displayedMonth = State(
            initialValue: Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: initialDate)
            ) ?? initialDate
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("大学カレンダー", systemImage: "calendar")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(datedEvents.count)件")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }

            if styledSchools.isEmpty || datedEvents.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(university.color.color)
                    Text("入試方式に日程を登録すると、ここに表示されます。")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(styledSchools.enumerated()), id: \.element.id) { _, school in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(school.color.color)
                                    .frame(width: 8, height: 8)
                                Text(school.method.isEmpty ? "方式名未入力" : school.method)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.primaryText)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 30)
                            .background(.white, in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(school.color.color.opacity(0.26), lineWidth: 1)
                            }
                        }
                    }
                }

                MonthGridView(
                    monthStart: displayedMonth,
                    selectedDate: $selectedDate,
                    events: datedEvents,
                    applicationRanges: applicationRanges,
                    showsUniversityNameInEvents: false,
                    onPreviousMonth: { moveMonth(by: -1) },
                    onNextMonth: { moveMonth(by: 1) }
                )

                selectedDaySummary
            }
        }
    }

    private var selectedDaySummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(selectedDate.formatted(.monthDayWeekday))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(selectedEvents.count + selectedActiveRanges.count)件")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            if selectedEvents.isEmpty && selectedActiveRanges.isEmpty {
                Text("この日の予定はありません。")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            } else {
                ForEach(selectedEvents) { event in
                    universityCalendarRow(
                        color: event.schoolColor.color,
                        title: event.title,
                        optionName: [event.faculty, event.optionName].filter { !$0.isEmpty }.joined(separator: "・"),
                        systemImage: event.kind.icon
                    )
                }

                ForEach(selectedActiveRanges) { range in
                    universityCalendarRow(
                        color: range.schoolColor.color,
                        title: "出願期間中",
                        optionName: [range.faculty, range.optionName].filter { !$0.isEmpty }.joined(separator: "・"),
                        systemImage: "arrow.left.and.right"
                    )
                }
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private func universityCalendarRow(
        color: Color,
        title: String,
        optionName: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                Text(optionName)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
        }
    }

    private var styledSchools: [ExamSchool] {
        university.examOptions.enumerated().map { index, option in
            var school = option.joined(with: university)
            school.color = calendarColor(at: index)
            return school
        }
    }

    private var datedEvents: [ExamEvent] {
        styledSchools.flatMap(\.events)
    }

    private var applicationRanges: [CalendarApplicationRange] {
        let ranges = styledSchools.compactMap { school -> CalendarApplicationRange? in
            guard let startDate = school.applicationStart, let endDate = school.applicationEnd else { return nil }
            return CalendarApplicationRange(
                universityID: university.id,
                examOptionID: school.id,
                schoolName: school.name,
                faculty: school.faculty,
                optionName: school.method,
                schoolColor: school.color,
                startDate: startDate,
                endDate: endDate
            )
        }
        return assignLanes(to: ranges)
    }

    private var selectedEvents: [ExamEvent] {
        datedEvents
            .filter { event in
                guard let date = event.date else { return false }
                return calendar.isDate(date, inSameDayAs: selectedDate)
            }
            .sorted { $0.kind.calendarPriority < $1.kind.calendarPriority }
    }

    private var selectedActiveRanges: [CalendarApplicationRange] {
        applicationRanges.filter { range in
            range.contains(selectedDate, calendar: calendar)
                && !range.isStart(selectedDate, calendar: calendar)
                && !range.isEnd(selectedDate, calendar: calendar)
        }
    }

    private func calendarColor(at index: Int) -> SchoolColor {
        if index == 0 {
            return university.color
        }
        let palette = SchoolColor.allCases
        let base = palette.firstIndex(of: university.color) ?? 0
        return palette[(base + index * 4) % palette.count]
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) ?? newMonth
        selectedDate = displayedMonth
    }

    private func assignLanes(to ranges: [CalendarApplicationRange]) -> [CalendarApplicationRange] {
        var laneEndDates: [Date] = []
        return ranges.sorted { $0.startDate < $1.startDate }.map { range in
            var styledRange = range
            if let lane = laneEndDates.firstIndex(where: {
                calendar.startOfDay(for: $0) < calendar.startOfDay(for: range.startDate)
            }) {
                styledRange.lane = lane
                laneEndDates[lane] = range.endDate
            } else {
                styledRange.lane = laneEndDates.count
                laneEndDates.append(range.endDate)
            }
            return styledRange
        }
    }
}

struct UniversitySummaryCard: View {
    var university: UniversityChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(String(university.name.prefix(1)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(university.color.color, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(university.name).font(.title3.weight(.bold))
                        if university.preferenceRank != nil {
                            PreferenceRankBadge(university: university)
                        }
                    }
                    Text("\(university.universityType.displayName) ・ 偏差値 \(university.deviationRangeText)")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            if hasLinks {
                Divider()
                if !university.officialAdmissionsURL.isEmpty {
                    UniversityLinkRow(title: "公式入試ページ", value: university.officialAdmissionsURL, tint: university.color.color)
                }
                if !university.admissionsGuidelineURL.isEmpty {
                    UniversityLinkRow(title: "入試要項", value: university.admissionsGuidelineURL, tint: university.color.color)
                }
                if !university.passnaviURL.isEmpty {
                    UniversityLinkRow(title: "パスナビ", value: university.passnaviURL, tint: university.color.color)
                }
                ForEach(university.customLinks.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { link in
                    UniversityLinkRow(
                        title: link.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "関連リンク" : link.name,
                        value: link.url,
                        tint: university.color.color
                    )
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .top) {
            Rectangle().fill(university.color.color).frame(height: 4)
        }
    }

    private var hasLinks: Bool {
        !university.officialAdmissionsURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !university.admissionsGuidelineURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || university.customLinks.contains { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !university.passnaviURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct UniversityLinkRow: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        if let url = URL(string: value) {
            Link(destination: url) {
                HStack {
                    Label(title, systemImage: "link")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            }
        }
    }
}

struct PreferenceRankBadge: View {
    var university: UniversityChoice

    var body: some View {
        Text(university.preferenceRankText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(university.color.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(university.color.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
    }
}

struct ExamOptionRow: View {
    var option: ExamOption
    var color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title.isEmpty ? "名称未入力" : option.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                HStack(spacing: 8) {
                    Text("偏差値 \(String(format: "%.1f", option.deviation))")
                    if let examDate = option.examDate {
                        Text("入試 \(examDate.formatted(.shortMonthDay))")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private enum SchoolAddRoute {
    case universityOnly
    case optionToExistingUniversity
    case universityAndOption
}

struct SchoolAddMenu: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var universities: [UniversityChoice]
    var nextColor: SchoolColor
    @State private var route: SchoolAddRoute?

    var body: some View {
        Group {
            switch route {
            case .universityOnly:
                UniversityEditorView(
                    university: .blank(nextColor: nextColor),
                    navigationTitle: "大学のみ追加"
                ) { university in
                    universities.append(university)
                }

            case .optionToExistingUniversity:
                AddExamOptionToExistingUniversityFlow(universities: $universities)

            case .universityAndOption:
                AddUniversityFlow(nextColor: nextColor) { university in
                    universities.append(university)
                }

            case nil:
                NavigationStack {
                    List {
                        Section {
                            addRouteButton(
                                title: "大学のみ追加",
                                description: "大学情報だけ登録し、入試方式はあとから追加",
                                systemImage: "building.columns",
                                route: .universityOnly
                            )

                            addRouteButton(
                                title: "既存の大学に入試方式を追加",
                                description: "登録済みの大学を選んで方式を追加",
                                systemImage: "doc.badge.plus",
                                route: .optionToExistingUniversity,
                                isEnabled: !universities.isEmpty
                            )

                            addRouteButton(
                                title: "大学と入試方式を追加",
                                description: "大学情報に続けて最初の方式も登録",
                                systemImage: "building.columns.fill",
                                route: .universityAndOption
                            )
                        }

                        if universities.isEmpty {
                            Section {
                                Label("既存大学への追加は、大学を1校以上登録すると選べます。", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                    }
                    .navigationTitle("追加する内容")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { dismiss() }
                        }
                    }
                }
            }
        }
    }

    private func addRouteButton(
        title: String,
        description: String,
        systemImage: String,
        route: SchoolAddRoute,
        isEnabled: Bool = true
    ) -> some View {
        Button {
            self.route = route
        } label: {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(isEnabled ? Color.uniexamIndigo : Color.secondaryText)
                    .frame(width: 38, height: 38)
                    .background(
                        (isEnabled ? Color.uniexamIndigo : Color.secondaryText).opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 7)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.primaryText)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondaryText)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityHint(description)
    }
}

struct AddExamOptionToExistingUniversityFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var universities: [UniversityChoice]
    @State private var selectedUniversityID: UUID?

    var body: some View {
        Group {
            if let universityIndex = selectedUniversityIndex {
                let university = universities[universityIndex]
                EditSchoolView(
                    mode: .add,
                    school: ExamOption.blank.joined(with: university),
                    fixedUniversity: university
                ) { school in
                    guard let currentIndex = universities.firstIndex(where: { $0.id == university.id }) else { return }
                    universities[currentIndex].examOptions.append(ExamOption(legacy: school))
                }
            } else {
                NavigationStack {
                    List(universities) { university in
                        Button {
                            selectedUniversityID = university.id
                        } label: {
                            HStack(spacing: 12) {
                                Text(String(university.name.prefix(1)))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(university.color.color, in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 7) {
                                        Text(university.name)
                                            .font(.headline)
                                        if university.preferenceRank != nil {
                                            PreferenceRankBadge(university: university)
                                        }
                                    }
                                    Text("\(university.universityType.displayName)・登録済み \(university.examOptions.count)方式")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(university.name)、登録済み\(university.examOptions.count)方式")
                    }
                    .navigationTitle("大学を選択")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { dismiss() }
                        }
                    }
                }
            }
        }
    }

    private var selectedUniversityIndex: Int? {
        guard let selectedUniversityID else { return nil }
        return universities.firstIndex { $0.id == selectedUniversityID }
    }
}

struct UniversityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var university: UniversityChoice
    var navigationTitle = "大学情報を編集"
    var onSave: (UniversityChoice) -> Void

    var body: some View {
        NavigationStack {
            Form {
                UniversityFormFields(university: $university)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(university)
                        dismiss()
                    }
                    .disabled(university.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AddUniversityFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var university: UniversityChoice
    @State private var isEnteringOption = false
    var onSave: (UniversityChoice) -> Void

    init(nextColor: SchoolColor, onSave: @escaping (UniversityChoice) -> Void) {
        _university = State(initialValue: .blank(nextColor: nextColor))
        self.onSave = onSave
    }

    var body: some View {
        Group {
            if isEnteringOption {
                EditSchoolView(mode: .add, school: ExamOption.blank.joined(with: university), fixedUniversity: university) { school in
                    university.examOptions = [ExamOption(legacy: school)]
                    onSave(university)
                }
            } else {
                NavigationStack {
                    Form {
                        Section {
                            Text("まず大学共通の情報を登録します。次の画面で最初の入試方式を入力します。")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                        UniversityFormFields(university: $university)
                    }
                    .navigationTitle("大学を追加")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("次へ") { isEnteringOption = true }
                                .disabled(university.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }
}

struct UniversityFormFields: View {
    @Binding var university: UniversityChoice

    var body: some View {
        Section("基本情報") {
            EditorTextField(
                title: "大学名",
                placeholder: "例：青葉大学",
                systemImage: "building.columns.fill",
                text: $university.name,
                isRequired: true
            )
            EditorTextField(
                title: "大学名（ふりがな）",
                placeholder: "例：あおばだいがく",
                systemImage: "textformat",
                text: $university.nameKana
            )
            VStack(alignment: .leading, spacing: 10) {
                EditorFieldLabel(title: "大学種別", systemImage: "building.2.crop.circle.fill", isRequired: true)
                Picker("大学種別", selection: $university.universityType) {
                    ForEach(UniversityType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            PreferenceRankPicker(selection: $university.preferenceRank)
            VStack(alignment: .leading, spacing: 10) {
                EditorFieldLabel(title: "大学カラー", systemImage: "paintpalette.fill", isRequired: true)
                SchoolColorPicker(selection: $university.color)
            }
        }

        Section("共通リンク") {
            EditorTextField(
                title: "公式入試ページURL",
                placeholder: "https://",
                systemImage: "link",
                text: $university.officialAdmissionsURL
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            EditorTextField(
                title: "入試要項URL",
                placeholder: "https://",
                systemImage: "doc.text",
                text: $university.admissionsGuidelineURL
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            EditorTextField(
                title: "パスナビURL",
                placeholder: "https://",
                systemImage: "link",
                text: $university.passnaviURL
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            ForEach($university.customLinks) { $link in
                UniversityCustomLinkEditor(
                    link: $link,
                    onDelete: {
                        university.customLinks.removeAll { $0.id == link.id }
                    }
                )
            }

            Button {
                university.customLinks.append(.blank)
            } label: {
                Label("任意のリンクを追加", systemImage: "plus.circle.fill")
            }
        }
    }
}

struct UniversityCustomLinkEditor: View {
    @Binding var link: UniversityResourceLink
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("任意リンク", systemImage: "link.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("このリンクを削除")
            }

            TextField("名称（例：大学公式サイト）", text: $link.name)
                .textInputAutocapitalization(.never)

            Divider()

            TextField("URL（https://）", text: $link.url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.vertical, 4)
    }
}

struct PreferenceRankPicker: View {
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text("志望順位")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
            } icon: {
                Image(systemName: "list.number")
                    .foregroundStyle(Color.uniexamIndigo)
                    .frame(width: 18)
            }

            Spacer()

            Menu {
                Button {
                    selection = nil
                } label: {
                    if selection == nil {
                        Label("未設定", systemImage: "checkmark")
                    } else {
                        Text("未設定")
                    }
                }

                ForEach(1...30, id: \.self) { rank in
                    Button {
                        selection = rank
                    } label: {
                        if selection == rank {
                            Label("第\(rank)志望", systemImage: "checkmark")
                        } else {
                            Text("第\(rank)志望")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection.map { "第\($0)志望" } ?? "未設定")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(selection == nil ? Color.secondaryText : Color.uniexamIndigo)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 7))
            }
            .accessibilityLabel("志望順位")
            .accessibilityValue(selection.map { "第\($0)志望" } ?? "未設定")
        }
        .padding(.vertical, 4)
    }
}
