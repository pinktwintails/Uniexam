import SwiftUI

struct MockExamResultsView: View {
    @Binding var results: [MockExamResult]
    let universities: [UniversityChoice]

    @Environment(\.dismiss) private var dismiss
    @State private var editingResult: MockExamResult?
    @State private var pendingDeletion: MockExamResult?

    var body: some View {
        NavigationStack {
            Group {
                if sortedResults.isEmpty {
                    ContentUnavailableView(
                        "模試結果がありません",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("右上の＋から最初の結果を登録できます。")
                    )
                } else {
                    List {
                        Section {
                            ForEach(sortedResults) { result in
                                Button {
                                    editingResult = result
                                } label: {
                                    MockExamResultRow(result: result)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDeletion = result
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text("最新の偏差値を戦略マップに反映")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("模試結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingResult = .blank()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("模試結果を追加")
                }
            }
            .navigationDestination(item: $editingResult) { result in
                MockExamResultEditor(
                    initialResult: result,
                    universities: universities,
                    onSave: save
                )
            }
            .alert("模試結果を削除しますか？", isPresented: deletionAlertBinding) {
                Button("キャンセル", role: .cancel) {
                    pendingDeletion = nil
                }
                Button("削除", role: .destructive) {
                    if let pendingDeletion {
                        results.removeAll { $0.id == pendingDeletion.id }
                    }
                    pendingDeletion = nil
                }
            } message: {
                Text(pendingDeletion?.name ?? "この模試結果")
            }
        }
    }

    private var sortedResults: [MockExamResult] {
        results.sorted { $0.date > $1.date }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func save(_ result: MockExamResult) {
        if let index = results.firstIndex(where: { $0.id == result.id }) {
            results[index] = result
        } else {
            results.append(result)
        }
    }
}

private struct MockExamResultRow: View {
    let result: MockExamResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(2)
                Spacer()
                Text(Self.dateFormatter.string(from: result.date))
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            HStack(spacing: 12) {
                resultMetric(title: "偏差値", value: result.deviation.formatted(.number.precision(.fractionLength(1))))
                if result.isCommonTestMock, let rate = result.commonTestScoreRate {
                    Divider().frame(height: 28)
                    resultMetric(title: "得点率", value: "\(rate.formatted(.number.precision(.fractionLength(0...1))))%")
                }
                Spacer()
                Label("\(result.judgments.count)方式", systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.uniexamIndigo)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func resultMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.secondaryText)
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.primaryText)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

private struct MockExamResultEditor: View {
    let universities: [UniversityChoice]
    let onSave: (MockExamResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var result: MockExamResult
    @State private var deviationText: String
    @State private var scoreRateText: String

    init(
        initialResult: MockExamResult,
        universities: [UniversityChoice],
        onSave: @escaping (MockExamResult) -> Void
    ) {
        self.universities = universities
        self.onSave = onSave
        _result = State(initialValue: initialResult)
        _deviationText = State(initialValue: initialResult.deviation.formatted(.number.precision(.fractionLength(1))))
        _scoreRateText = State(
            initialValue: initialResult.commonTestScoreRate?.formatted(.number.precision(.fractionLength(0...1))) ?? ""
        )
    }

    var body: some View {
        Form {
            Section("模試情報") {
                TextField("模試名", text: $result.name)

                DatePicker("受験日", selection: $result.date, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                HStack {
                    Text("偏差値")
                    Spacer()
                    TextField("60.0", text: $deviationText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
            }

            Section {
                Toggle("共通テスト模試", isOn: $result.isCommonTestMock)

                if result.isCommonTestMock {
                    HStack {
                        Text("得点率")
                        Spacer()
                        TextField("75", text: $scoreRateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            } footer: {
                Text("得点率は共通テスト模試の場合だけ保存されます。")
            }

            Section {
                NavigationLink {
                    MockExamJudgmentSelectionView(
                        judgments: $result.judgments,
                        universities: universities
                    )
                } label: {
                    HStack {
                        Label("判定を登録", systemImage: "checklist")
                        Spacer()
                        Text("\(result.judgments.count)方式")
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                ForEach(result.judgments) { judgment in
                    let tint = universityColor(for: judgment.universityID)

                    HStack(alignment: .center, spacing: 12) {
                        Text(judgment.grade.rawValue)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.primaryText)
                            .frame(minWidth: 64, minHeight: 38)
                            .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(tint.opacity(0.30), lineWidth: 1)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(judgment.universityName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                            Text(judgment.examOptionName.isEmpty ? "方式名未入力" : judgment.examOptionName)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("志望校判定")
            } footer: {
                Text("非表示中の大学・入試方式も選択できます。")
            }
        }
        .navigationTitle(result.name.isEmpty ? "模試結果を追加" : "模試結果を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(isSaveDisabled)
            }
        }
    }

    private var parsedDeviation: Double? {
        Double(deviationText.replacingOccurrences(of: "，", with: ".").replacingOccurrences(of: ",", with: "."))
    }

    private var parsedScoreRate: Double? {
        guard !scoreRateText.isEmpty else { return nil }
        return Double(scoreRateText.replacingOccurrences(of: "，", with: ".").replacingOccurrences(of: ",", with: "."))
    }

    private var isSaveDisabled: Bool {
        result.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || parsedDeviation == nil
            || !(0...100).contains(parsedDeviation ?? -1)
            || (result.isCommonTestMock && parsedScoreRate.map { !(0...100).contains($0) } == true)
    }

    private func save() {
        guard let parsedDeviation else { return }
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.deviation = parsedDeviation
        result.commonTestScoreRate = result.isCommonTestMock ? parsedScoreRate : nil
        onSave(result)
        dismiss()
    }

    private func universityColor(for universityID: UUID) -> Color {
        universities.first(where: { $0.id == universityID })?.color.color ?? .uniexamIndigo
    }
}

private struct MockExamJudgmentSelectionView: View {
    @Binding var judgments: [MockExamJudgment]
    let universities: [UniversityChoice]

    var body: some View {
        List {
            ForEach(sortedUniversities) { university in
                Section {
                    ForEach(university.examOptions) { option in
                        judgmentRow(university: university, option: option)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(university.color.color)
                            .frame(width: 8, height: 8)
                        Text(university.name)
                            .font(.subheadline.weight(.semibold))
                        if university.isHidden {
                            Text("非表示")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                }
            }
        }
        .navigationTitle("判定する方式")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedUniversities: [UniversityChoice] {
        universities.sorted {
            $0.nameKana.isEmpty
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.nameKana.localizedStandardCompare($1.nameKana) == .orderedAscending
        }
    }

    private func judgmentRow(university: UniversityChoice, option: ExamOption) -> some View {
        let selected = judgmentIndex(optionID: option.id) != nil
        let tint = university.color.color

        return HStack(spacing: 12) {
            Button {
                toggle(university: university, option: option)
            } label: {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? tint : Color.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selected ? "判定対象から外す" : "判定対象に追加")

            VStack(alignment: .leading, spacing: 3) {
                Text(option.title.isEmpty ? "方式名未入力" : option.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primaryText)
                if option.isHidden {
                    Text("非表示中の入試方式")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Spacer()

            if selected {
                Menu {
                    ForEach(MockExamJudgmentGrade.allCases) { grade in
                        Button {
                            gradeBinding(optionID: option.id).wrappedValue = grade
                        } label: {
                            if gradeBinding(optionID: option.id).wrappedValue == grade {
                                Label(grade.rawValue, systemImage: "checkmark")
                            } else {
                                Text(grade.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(gradeBinding(optionID: option.id).wrappedValue.rawValue)
                            .font(.subheadline.weight(.bold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.primaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(tint.opacity(0.30), lineWidth: 1)
                    }
                }
                .accessibilityLabel("判定")
                .accessibilityValue(gradeBinding(optionID: option.id).wrappedValue.rawValue)
            }
        }
        .padding(.vertical, 3)
    }

    private func judgmentIndex(optionID: UUID) -> Int? {
        judgments.firstIndex { $0.examOptionID == optionID }
    }

    private func gradeBinding(optionID: UUID) -> Binding<MockExamJudgmentGrade> {
        Binding(
            get: {
                guard let index = judgmentIndex(optionID: optionID) else { return .c }
                return judgments[index].grade
            },
            set: { newValue in
                guard let index = judgmentIndex(optionID: optionID) else { return }
                judgments[index].grade = newValue
            }
        )
    }

    private func toggle(university: UniversityChoice, option: ExamOption) {
        if let index = judgmentIndex(optionID: option.id) {
            judgments.remove(at: index)
        } else {
            judgments.append(
                MockExamJudgment(
                    universityID: university.id,
                    examOptionID: option.id,
                    universityName: university.name,
                    examOptionName: option.title,
                    grade: .c
                )
            )
        }
    }
}
