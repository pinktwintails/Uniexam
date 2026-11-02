import Foundation

enum ExamOptionCategory: String, CaseIterable, Identifiable, Codable {
    case commonTestOnly = "共テ単独"
    case general = "一般"

    var id: String { rawValue }

    static func inferred(from method: String) -> ExamOptionCategory {
        let normalized = method.replacingOccurrences(of: " ", with: "")
        let mentionsCommonTest = normalized.contains("共テ") || normalized.contains("共通テスト")
        return mentionsCommonTest && !normalized.contains("併用") ? .commonTestOnly : .general
    }
}

enum DocumentMailingDeadlineRule: String, CaseIterable, Identifiable, Codable {
    case mustArrive = "必着"
    case postmarkAccepted = "消印有効"

    var id: String { rawValue }
}

struct ExamChecklistItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var isCompleted = false
    var isPreset = false

    static var defaultItems: [ExamChecklistItem] {
        [
            ExamChecklistItem(title: "募集要項を確認", isPreset: true),
            ExamChecklistItem(title: "出願サイト登録", isPreset: true),
            ExamChecklistItem(title: "出願", isPreset: true),
            ExamChecklistItem(title: "試験料支払い", isPreset: true),
            ExamChecklistItem(title: "書類を郵送", isPreset: true),
            ExamChecklistItem(title: "受験票を印刷", isPreset: true),
            ExamChecklistItem(title: "当日の行き方を確認", isPreset: true)
        ]
    }
}

struct ExamRequiredDocument: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var isCompleted = false

    static func reconciled(
        from text: String,
        preserving existingItems: [ExamRequiredDocument] = []
    ) -> [ExamRequiredDocument] {
        let separators = CharacterSet(charactersIn: "、，,\n;；")
        var seenTitles = Set<String>()

        return text
            .components(separatedBy: separators)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "・-−—•"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .filter { seenTitles.insert($0).inserted }
            .map { title in
                existingItems.first(where: { $0.title == title })
                    ?? ExamRequiredDocument(title: title)
            }
    }
}

struct ExamCustomScheduleItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var date: Date
}

struct UniversityResourceLink: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var url: String

    static var blank: UniversityResourceLink {
        UniversityResourceLink(name: "", url: "")
    }
}

struct UniversityChoice: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var nameKana: String
    var universityType: UniversityType
    var color: SchoolColor
    var preferenceRank: Int? = nil
    var isHidden = false
    var officialAdmissionsURL: String
    var admissionsGuidelineURL: String
    var applicationURL: String
    var customLinks: [UniversityResourceLink]
    var passnaviURL: String
    var examOptions: [ExamOption]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameKana
        case universityType
        case color
        case preferenceRank
        case isHidden
        case officialAdmissionsURL
        case admissionsGuidelineURL
        case applicationURL
        case customLinks
        case passnaviURL
        case examOptions
    }

    init(
        id: UUID = UUID(),
        name: String,
        nameKana: String,
        universityType: UniversityType,
        color: SchoolColor,
        preferenceRank: Int? = nil,
        isHidden: Bool = false,
        officialAdmissionsURL: String,
        admissionsGuidelineURL: String = "",
        applicationURL: String = "",
        customLinks: [UniversityResourceLink] = [],
        passnaviURL: String,
        examOptions: [ExamOption]
    ) {
        self.id = id
        self.name = name
        self.nameKana = nameKana
        self.universityType = universityType
        self.color = color
        self.preferenceRank = preferenceRank
        self.isHidden = isHidden
        self.officialAdmissionsURL = officialAdmissionsURL
        self.admissionsGuidelineURL = admissionsGuidelineURL.isEmpty
            ? examOptions.first(where: { !$0.guidelineURL.isEmpty })?.guidelineURL ?? ""
            : admissionsGuidelineURL
        self.applicationURL = applicationURL.isEmpty
            ? examOptions.first(where: { !$0.applicationURL.isEmpty })?.applicationURL ?? ""
            : applicationURL
        self.customLinks = customLinks
        self.passnaviURL = passnaviURL
        self.examOptions = examOptions.map { option in
            var normalized = option
            normalized.guidelineURL = ""
            normalized.applicationURL = ""
            return normalized
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        nameKana = try container.decodeIfPresent(String.self, forKey: .nameKana) ?? ""
        universityType = try container.decode(UniversityType.self, forKey: .universityType)
        color = try container.decode(SchoolColor.self, forKey: .color)
        preferenceRank = try container.decodeIfPresent(Int.self, forKey: .preferenceRank)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        officialAdmissionsURL = try container.decodeIfPresent(String.self, forKey: .officialAdmissionsURL) ?? ""
        admissionsGuidelineURL = try container.decodeIfPresent(String.self, forKey: .admissionsGuidelineURL) ?? ""
        applicationURL = try container.decodeIfPresent(String.self, forKey: .applicationURL) ?? ""
        customLinks = try container.decodeIfPresent([UniversityResourceLink].self, forKey: .customLinks) ?? []
        passnaviURL = try container.decodeIfPresent(String.self, forKey: .passnaviURL) ?? ""
        examOptions = try container.decodeIfPresent([ExamOption].self, forKey: .examOptions) ?? []
        if admissionsGuidelineURL.isEmpty {
            admissionsGuidelineURL = examOptions.first(where: { !$0.guidelineURL.isEmpty })?.guidelineURL ?? ""
        }
        if applicationURL.isEmpty {
            applicationURL = examOptions.first(where: { !$0.applicationURL.isEmpty })?.applicationURL ?? ""
        }
        examOptions = examOptions.map { option in
            var normalized = option
            normalized.guidelineURL = ""
            normalized.applicationURL = ""
            return normalized
        }
    }

    var deviationRangeText: String {
        let values = examOptions.filter { !$0.isHidden }.map(\.deviation)
        guard let minimum = values.min(), let maximum = values.max() else { return "未登録" }
        if minimum == maximum {
            return String(format: "%.1f", minimum)
        }
        return "\(String(format: "%.1f", minimum))〜\(String(format: "%.1f", maximum))"
    }

    var maximumDeviation: Double {
        examOptions.filter { !$0.isHidden }.map(\.deviation).max() ?? 0
    }

    var earliestExamDate: Date? {
        examOptions.filter { !$0.isHidden }.compactMap(\.examDate).min()
    }

    var nextEvent: ExamEvent? {
        joinedSchools.filter { !$0.isHidden }
            .flatMap(\.events)
            .filter { ($0.date ?? .distantPast) >= .demoToday }
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    var joinedSchools: [ExamSchool] {
        examOptions.map { $0.joined(with: self) }
    }

    var preferenceRankText: String {
        guard let preferenceRank else { return "未設定" }
        return "第\(preferenceRank)志望"
    }

    static func blank(nextColor: SchoolColor = .blue) -> UniversityChoice {
        UniversityChoice(
            name: "",
            nameKana: "",
            universityType: .privateSchool,
            color: nextColor,
            officialAdmissionsURL: "",
            admissionsGuidelineURL: "",
            applicationURL: "",
            customLinks: [],
            passnaviURL: "",
            examOptions: []
        )
    }

    private static func sampleChecklist(
        completedTitles: Set<String>,
        customTitles: [String] = []
    ) -> [ExamChecklistItem] {
        let presetItems = ExamChecklistItem.defaultItems.map { item in
            var updated = item
            updated.isCompleted = completedTitles.contains(item.title)
            return updated
        }
        let customItems = customTitles.map { title in
            ExamChecklistItem(
                title: title,
                isCompleted: completedTitles.contains(title),
                isPreset: false
            )
        }
        return presetItems + customItems
    }

    private static func sampleDocuments(
        _ titles: [String],
        completedTitles: Set<String> = []
    ) -> [ExamRequiredDocument] {
        titles.map { title in
            ExamRequiredDocument(title: title, isCompleted: completedTitles.contains(title))
        }
    }

    private static func sampleSchedule(_ title: String, year: Int, month: Int, day: Int) -> ExamCustomScheduleItem {
        ExamCustomScheduleItem(
            id: UUID(),
            title: title,
            date: .from(year: year, month: month, day: day)
        )
    }

    // Keep these fixtures in sync whenever university or exam-option input fields change.
    static var samples: [UniversityChoice] {
        [
            UniversityChoice(
                name: "青葉大学",
                nameKana: "あおばだいがく",
                universityType: .privateSchool,
                color: .blue,
                preferenceRank: 2,
                officialAdmissionsURL: "https://admissions.aoba-u.example/",
                admissionsGuidelineURL: "https://admissions.aoba-u.example/guideline-2027.pdf",
                applicationURL: "https://entry.aoba-u.example/",
                customLinks: [
                    UniversityResourceLink(
                        name: "入試FAQ",
                        url: "https://admissions.aoba-u.example/faq/"
                    )
                ],
                passnaviURL: "https://passnavi.example/aoba",
                examOptions: [
                    ExamOption(
                        faculty: "経済学部",
                        method: "共通テスト利用3科目型",
                        admissionCategory: .commonTestOnly,
                        deviation: 60,
                        examDate: nil,
                        applicationStart: .from(year: 2027, month: 1, day: 5),
                        applicationEnd: .from(year: 2027, month: 1, day: 18),
                        paymentDeadline: .from(year: 2027, month: 1, day: 19),
                        documentMailingDeadline: .from(year: 2027, month: 1, day: 18),
                        documentMailingDeadlineRule: .postmarkAccepted,
                        requiredDocuments: "調査書、共通テスト成績請求票、写真",
                        resultDate: .from(year: 2027, month: 2, day: 10),
                        admissionFeeDeadline: .from(year: 2027, month: 2, day: 22),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 8),
                        guidelineURL: "https://admissions.aoba-u.example/economics/common-test.pdf",
                        applicationURL: "https://entry.aoba-u.example/",
                        subjects: [],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語（リーディング）", score: "100点"),
                            SubjectScore(subject: "英語（リスニング）", score: "100点"),
                            SubjectScore(subject: "現代文", score: "110点"),
                            SubjectScore(subject: "古文", score: "45点"),
                            SubjectScore(subject: "漢文", score: "45点"),
                            SubjectScore(subject: "数学I・A", score: "100点")
                        ],
                        externalEnglishSubjects: [
                            SubjectScore(subject: "英検CSE 2300以上", score: "20点")
                        ],
                        externalEnglishMemo: "英検CSE 2300以上は20点加点。共通テスト英語との合計は200点を上限とする。",
                        commonTestBorderRate: "72",
                        minimumPassingScore: "365/500点",
                        acceptanceRatio: "2.3倍",
                        capacity: "35名",
                        memo: "共通テストの自己採点後に出願内容を最終確認",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認", "出願サイト登録"]),
                        customScheduleItems: [
                            sampleSchedule("成績請求票を取り寄せ", year: 2026, month: 12, day: 18)
                        ]
                    ),
                    ExamOption(
                        faculty: "経済学部",
                        method: "一般A方式",
                        admissionCategory: .general,
                        deviation: 62,
                        examDate: .from(year: 2027, month: 2, day: 10),
                        applicationStart: .from(year: 2027, month: 1, day: 5),
                        applicationEnd: .from(year: 2027, month: 1, day: 25),
                        paymentDeadline: .from(year: 2027, month: 1, day: 26),
                        documentMailingDeadline: .from(year: 2027, month: 1, day: 25),
                        documentMailingDeadlineRule: .mustArrive,
                        requiredDocuments: "調査書、志望理由書、写真",
                        resultDate: .from(year: 2027, month: 2, day: 18),
                        admissionFeeDeadline: .from(year: 2027, month: 2, day: 25),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 8),
                        guidelineURL: "https://admissions.aoba-u.example/economics/general-a.pdf",
                        applicationURL: "https://entry.aoba-u.example/",
                        subjects: [
                            SubjectScore(subject: "英語", score: "200点"),
                            SubjectScore(subject: "国語", score: "150点"),
                            SubjectScore(subject: "数学", score: "150点")
                        ],
                        commonTestSubjects: [],
                        externalEnglishSubjects: [
                            SubjectScore(subject: "英検2級以上", score: "10点")
                        ],
                        externalEnglishMemo: "英検2級以上は英語の得点に10点加点。",
                        minimumPassingScore: "378/500点",
                        acceptanceRatio: "2.6倍",
                        capacity: "80名",
                        memo: "英語の配点が高いので直前期に重点確認",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認"]),
                        customScheduleItems: [
                            sampleSchedule("過去問2周目を開始", year: 2027, month: 1, day: 10)
                        ]
                    ),
                    ExamOption(
                        isHidden: true,
                        faculty: "国際学部",
                        method: "英語外部利用方式",
                        admissionCategory: .general,
                        deviation: 61.5,
                        examDate: .from(year: 2027, month: 2, day: 12),
                        applicationStart: .from(year: 2027, month: 1, day: 5),
                        applicationEnd: .from(year: 2027, month: 1, day: 24),
                        paymentDeadline: .from(year: 2027, month: 1, day: 25),
                        documentMailingDeadline: .from(year: 2027, month: 1, day: 24),
                        documentMailingDeadlineRule: .postmarkAccepted,
                        requiredDocuments: "調査書、英語資格証明書、写真、志望理由書",
                        requiredDocumentItems: sampleDocuments(
                            ["調査書", "英語資格証明書", "写真", "志望理由書"],
                            completedTitles: ["写真"]
                        ),
                        resultDate: .from(year: 2027, month: 2, day: 20),
                        admissionFeeDeadline: .from(year: 2027, month: 2, day: 27),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 10),
                        guidelineURL: "",
                        applicationURL: "",
                        subjects: [
                            SubjectScore(subject: "国語", score: "150点"),
                            SubjectScore(subject: "小論文", score: "100点")
                        ],
                        commonTestSubjects: [],
                        externalEnglishSubjects: [
                            SubjectScore(subject: "英検準1級", score: "150点"),
                            SubjectScore(subject: "TEAP 300以上", score: "140点")
                        ],
                        externalEnglishMemo: "英検とTEAPのうち高い換算点を採用。証明書は原本提出。",
                        minimumPassingScore: "292",
                        acceptanceRatio: "3.8倍",
                        capacity: "24名",
                        memo: "比較検討中のため非表示。英語資格の有効期限を確認する。",
                        checklistItems: sampleChecklist(
                            completedTitles: ["募集要項を確認", "英語資格の有効期限を確認"],
                            customTitles: ["英語資格の有効期限を確認"]
                        ),
                        customScheduleItems: [
                            sampleSchedule("英語資格証明書を発行申請", year: 2026, month: 12, day: 15),
                            sampleSchedule("志望理由書の添削", year: 2027, month: 1, day: 12)
                        ]
                    )
                ]
            ),
            UniversityChoice(
                name: "桜丘大学",
                nameKana: "さくらおかだいがく",
                universityType: .privateSchool,
                color: .rosePink,
                preferenceRank: 3,
                officialAdmissionsURL: "https://nyushi.sakuraoka-u.example/",
                admissionsGuidelineURL: "https://nyushi.sakuraoka-u.example/guide-2027.pdf",
                applicationURL: "https://entry.sakuraoka-u.example/",
                customLinks: [
                    UniversityResourceLink(
                        name: "受験生向けアクセス",
                        url: "https://nyushi.sakuraoka-u.example/access/"
                    )
                ],
                passnaviURL: "https://passnavi.example/sakuraoka",
                examOptions: [
                    ExamOption(
                        faculty: "法学部",
                        method: "共テ利用前期",
                        admissionCategory: .commonTestOnly,
                        deviation: 58,
                        examDate: nil,
                        applicationStart: .from(year: 2027, month: 1, day: 4),
                        applicationEnd: .from(year: 2027, month: 1, day: 16),
                        paymentDeadline: .from(year: 2027, month: 1, day: 17),
                        documentMailingDeadline: .from(year: 2027, month: 1, day: 16),
                        documentMailingDeadlineRule: .postmarkAccepted,
                        requiredDocuments: "調査書、共通テスト成績請求票",
                        resultDate: .from(year: 2027, month: 2, day: 14),
                        admissionFeeDeadline: .from(year: 2027, month: 2, day: 21),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 5),
                        guidelineURL: "https://nyushi.sakuraoka-u.example/law/common-test.pdf",
                        applicationURL: "https://entry.sakuraoka-u.example/",
                        subjects: [],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語（リーディング）", score: "100点"),
                            SubjectScore(subject: "英語（リスニング）", score: "100点"),
                            SubjectScore(subject: "現代文", score: "110点"),
                            SubjectScore(subject: "古文", score: "45点"),
                            SubjectScore(subject: "漢文", score: "45点"),
                            SubjectScore(subject: "歴史総合・日本史探究", score: "100点")
                        ],
                        externalEnglishSubjects: [
                            SubjectScore(subject: "TEAP 225以上", score: "15点")
                        ],
                        externalEnglishMemo: "TEAP 225以上は15点、英検準1級は20点として高い方を採用。",
                        commonTestBorderRate: "68",
                        minimumPassingScore: "352/500点",
                        acceptanceRatio: "3.1倍",
                        capacity: "45名",
                        memo: "英語はリーディングとリスニングを合算",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認", "出願サイト登録", "出願"]),
                        customScheduleItems: [
                            sampleSchedule("調査書を受け取る", year: 2027, month: 1, day: 8)
                        ]
                    ),
                    ExamOption(
                        faculty: "法学部",
                        method: "一般B方式",
                        admissionCategory: .general,
                        deviation: 59.5,
                        examDate: .from(year: 2027, month: 2, day: 17),
                        applicationStart: .from(year: 2027, month: 1, day: 6),
                        applicationEnd: .from(year: 2027, month: 1, day: 28),
                        paymentDeadline: .from(year: 2027, month: 1, day: 28),
                        documentMailingDeadline: .from(year: 2027, month: 1, day: 28),
                        documentMailingDeadlineRule: .mustArrive,
                        requiredDocuments: "調査書、志願票、写真、活動報告書",
                        resultDate: .from(year: 2027, month: 2, day: 24),
                        admissionFeeDeadline: .from(year: 2027, month: 3, day: 3),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 12),
                        guidelineURL: "https://nyushi.sakuraoka-u.example/law/general-b.pdf",
                        applicationURL: "https://entry.sakuraoka-u.example/",
                        subjects: [
                            SubjectScore(subject: "英語", score: "150点"),
                            SubjectScore(subject: "国語", score: "150点"),
                            SubjectScore(subject: "日本史", score: "100点")
                        ],
                        commonTestSubjects: [],
                        externalEnglishSubjects: [],
                        minimumPassingScore: "286",
                        acceptanceRatio: "3.4倍",
                        capacity: "55名",
                        memo: "国語の配点が高い方式。過去問の時間配分を確認する",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認"]),
                        customScheduleItems: [
                            sampleSchedule("受験票公開予定", year: 2027, month: 2, day: 8)
                        ]
                    )
                ]
            ),
            UniversityChoice(
                name: "東都大学",
                nameKana: "とうとだいがく",
                universityType: .nationalPublic,
                color: .teal,
                preferenceRank: 1,
                officialAdmissionsURL: "https://admissions.toto-u.example/",
                admissionsGuidelineURL: "https://admissions.toto-u.example/requirements-2027.pdf",
                applicationURL: "https://entry.toto-u.example/",
                customLinks: [
                    UniversityResourceLink(
                        name: "キャンパスマップ",
                        url: "https://www.toto-u.example/campus-map/"
                    )
                ],
                passnaviURL: "https://passnavi.example/toto",
                examOptions: [
                    ExamOption(
                        faculty: "文学部",
                        method: "前期日程",
                        admissionCategory: .general,
                        deviation: 65,
                        examDate: .from(year: 2027, month: 2, day: 25),
                        applicationStart: .from(year: 2027, month: 1, day: 18),
                        applicationEnd: .from(year: 2027, month: 2, day: 3),
                        paymentDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadlineRule: .mustArrive,
                        requiredDocuments: "調査書、志願票、共通テスト成績請求票",
                        resultDate: .from(year: 2027, month: 3, day: 8),
                        admissionFeeDeadline: .from(year: 2027, month: 3, day: 15),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 27),
                        guidelineURL: "https://admissions.toto-u.example/literature/first-term.pdf",
                        applicationURL: "https://entry.toto-u.example/",
                        subjects: [
                            SubjectScore(subject: "英語", score: "200点"),
                            SubjectScore(subject: "国語", score: "200点"),
                            SubjectScore(subject: "小論文", score: "100点")
                        ],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語（リーディング）", score: "100点"),
                            SubjectScore(subject: "英語（リスニング）", score: "100点"),
                            SubjectScore(subject: "現代文", score: "110点"),
                            SubjectScore(subject: "古文", score: "45点"),
                            SubjectScore(subject: "漢文", score: "45点"),
                            SubjectScore(subject: "歴史総合・日本史探究", score: "200点"),
                            SubjectScore(subject: "数学I・A", score: "100点"),
                            SubjectScore(subject: "数学II・B・C", score: "100点"),
                            SubjectScore(subject: "情報I", score: "100点")
                        ],
                        externalEnglishSubjects: [
                            SubjectScore(subject: "英検準1級", score: "30点")
                        ],
                        externalEnglishMemo: "英検準1級は個別試験の英語に30点加点。",
                        commonTestBorderRate: "78",
                        minimumPassingScore: "742/1400点",
                        acceptanceRatio: "2.1倍",
                        capacity: "60名",
                        memo: "合格発表から入学金締切までが短い",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認", "当日の行き方を確認"]),
                        customScheduleItems: [
                            sampleSchedule("ホテル予約の確認", year: 2027, month: 2, day: 10)
                        ]
                    ),
                    ExamOption(
                        faculty: "教育学部",
                        method: "前期日程",
                        admissionCategory: .general,
                        deviation: 63,
                        examDate: .from(year: 2027, month: 2, day: 26),
                        applicationStart: .from(year: 2027, month: 1, day: 18),
                        applicationEnd: .from(year: 2027, month: 2, day: 3),
                        paymentDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadlineRule: .postmarkAccepted,
                        requiredDocuments: "調査書、志願票、共通テスト成績請求票、活動報告書",
                        resultDate: .from(year: 2027, month: 3, day: 8),
                        admissionFeeDeadline: .from(year: 2027, month: 3, day: 15),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 27),
                        guidelineURL: "https://admissions.toto-u.example/education/first-term.pdf",
                        applicationURL: "https://entry.toto-u.example/",
                        subjects: [
                            SubjectScore(subject: "英語", score: "150点"),
                            SubjectScore(subject: "国語", score: "150点"),
                            SubjectScore(subject: "面接", score: "100点")
                        ],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語（リーディング）", score: "100点"),
                            SubjectScore(subject: "英語（リスニング）", score: "100点"),
                            SubjectScore(subject: "現代文", score: "110点"),
                            SubjectScore(subject: "古文", score: "45点"),
                            SubjectScore(subject: "漢文", score: "45点"),
                            SubjectScore(subject: "歴史総合・日本史探究", score: "200点"),
                            SubjectScore(subject: "数学I・A", score: "100点"),
                            SubjectScore(subject: "数学II・B・C", score: "100点"),
                            SubjectScore(subject: "生物", score: "100点"),
                            SubjectScore(subject: "情報I", score: "100点")
                        ],
                        commonTestBorderRate: "76",
                        minimumPassingScore: "718/1300点",
                        acceptanceRatio: "2.8倍",
                        capacity: "40名",
                        memo: "面接用に活動報告書の内容を整理しておく",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認"]),
                        customScheduleItems: [
                            sampleSchedule("面接練習", year: 2027, month: 2, day: 18)
                        ]
                    ),
                    ExamOption(
                        faculty: "法学部",
                        method: "後期日程",
                        admissionCategory: .general,
                        deviation: 66,
                        examDate: .from(year: 2027, month: 3, day: 12),
                        applicationStart: .from(year: 2027, month: 1, day: 18),
                        applicationEnd: .from(year: 2027, month: 2, day: 3),
                        paymentDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadlineRule: .mustArrive,
                        requiredDocuments: "調査書、志願票、共通テスト成績請求票、志望理由書",
                        resultDate: .from(year: 2027, month: 3, day: 21),
                        admissionFeeDeadline: .from(year: 2027, month: 3, day: 26),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 31),
                        guidelineURL: "https://admissions.toto-u.example/law/later-term.pdf",
                        applicationURL: "https://entry.toto-u.example/",
                        subjects: [
                            SubjectScore(subject: "小論文", score: "200点"),
                            SubjectScore(subject: "面接", score: "100点")
                        ],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語", score: "200点"),
                            SubjectScore(subject: "国語", score: "200点"),
                            SubjectScore(subject: "社会", score: "200点"),
                            SubjectScore(subject: "数学", score: "200点"),
                            SubjectScore(subject: "情報I", score: "100点")
                        ],
                        externalEnglishSubjects: [],
                        commonTestBorderRate: "80",
                        minimumPassingScore: "706",
                        acceptanceRatio: "4.2倍",
                        capacity: "18名",
                        memo: "後期日程。小論文と面接の準備を優先する",
                        checklistItems: sampleChecklist(completedTitles: ["募集要項を確認", "当日の行き方を確認"]),
                        customScheduleItems: [
                            sampleSchedule("小論文添削の最終提出", year: 2027, month: 3, day: 5)
                        ]
                    )
                ]
            ),
            UniversityChoice(
                name: "北浜市立大学",
                nameKana: "きたはましりつだいがく",
                universityType: .nationalPublic,
                color: .amber,
                preferenceRank: 4,
                isHidden: true,
                officialAdmissionsURL: "https://admissions.kitahama-u.example/",
                admissionsGuidelineURL: "https://admissions.kitahama-u.example/guide-2027.pdf",
                applicationURL: "https://entry.kitahama-u.example/",
                customLinks: [
                    UniversityResourceLink(
                        name: "学部紹介",
                        url: "https://www.kitahama-u.example/faculty/"
                    ),
                    UniversityResourceLink(
                        name: "試験会場案内",
                        url: "https://admissions.kitahama-u.example/access/"
                    )
                ],
                passnaviURL: "https://passnavi.example/kitahama",
                examOptions: [
                    ExamOption(
                        faculty: "情報科学部",
                        method: "共テ単独6科目型",
                        admissionCategory: .commonTestOnly,
                        deviation: 56.5,
                        examDate: nil,
                        applicationStart: .from(year: 2027, month: 1, day: 12),
                        applicationEnd: .from(year: 2027, month: 1, day: 30),
                        paymentDeadline: .from(year: 2027, month: 1, day: 30),
                        documentMailingDeadline: .from(year: 2027, month: 1, day: 30),
                        documentMailingDeadlineRule: .postmarkAccepted,
                        requiredDocuments: "調査書、志願票、共通テスト成績請求票、写真",
                        requiredDocumentItems: sampleDocuments(
                            ["調査書", "志願票", "共通テスト成績請求票", "写真"],
                            completedTitles: ["写真"]
                        ),
                        resultDate: .from(year: 2027, month: 2, day: 16),
                        admissionFeeDeadline: .from(year: 2027, month: 2, day: 24),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 10),
                        guidelineURL: "",
                        applicationURL: "",
                        subjects: [],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語（リーディング）", score: "100点"),
                            SubjectScore(subject: "英語（リスニング）", score: "100点"),
                            SubjectScore(subject: "現代文", score: "110点"),
                            SubjectScore(subject: "古文", score: "45点"),
                            SubjectScore(subject: "漢文", score: "45点"),
                            SubjectScore(subject: "数学", score: "200点"),
                            SubjectScore(subject: "物理", score: "100点"),
                            SubjectScore(subject: "化学", score: "100点"),
                            SubjectScore(subject: "社会", score: "100点"),
                            SubjectScore(subject: "情報I", score: "100点")
                        ],
                        externalEnglishSubjects: [],
                        commonTestBorderRate: "69",
                        minimumPassingScore: "724",
                        acceptanceRatio: "2.7倍",
                        capacity: "30名",
                        memo: "共通テスト自己採点後に出願を再検討する候補。",
                        checklistItems: sampleChecklist(
                            completedTitles: ["募集要項を確認", "共通テストの換算表を確認"],
                            customTitles: ["共通テストの換算表を確認"]
                        ),
                        customScheduleItems: [
                            sampleSchedule("共テ換算点を試算", year: 2027, month: 1, day: 18)
                        ]
                    ),
                    ExamOption(
                        faculty: "情報科学部",
                        method: "前期日程",
                        admissionCategory: .general,
                        deviation: 57.5,
                        examDate: .from(year: 2027, month: 2, day: 25),
                        applicationStart: .from(year: 2027, month: 1, day: 18),
                        applicationEnd: .from(year: 2027, month: 2, day: 3),
                        paymentDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadline: .from(year: 2027, month: 2, day: 3),
                        documentMailingDeadlineRule: .mustArrive,
                        requiredDocuments: "調査書、志願票、共通テスト成績請求票、活動実績書、写真",
                        requiredDocumentItems: sampleDocuments(
                            ["調査書", "志願票", "共通テスト成績請求票", "活動実績書", "写真"],
                            completedTitles: ["活動実績書", "写真"]
                        ),
                        resultDate: .from(year: 2027, month: 3, day: 7),
                        admissionFeeDeadline: .from(year: 2027, month: 3, day: 14),
                        tuitionDeadline: .from(year: 2027, month: 3, day: 24),
                        guidelineURL: "",
                        applicationURL: "",
                        subjects: [
                            SubjectScore(subject: "数学", score: "300点"),
                            SubjectScore(subject: "英語", score: "150点"),
                            SubjectScore(subject: "情報", score: "150点")
                        ],
                        commonTestSubjects: [
                            SubjectScore(subject: "英語", score: "200点"),
                            SubjectScore(subject: "国語", score: "200点"),
                            SubjectScore(subject: "数学", score: "200点"),
                            SubjectScore(subject: "理科", score: "200点"),
                            SubjectScore(subject: "社会", score: "100点"),
                            SubjectScore(subject: "情報I", score: "100点")
                        ],
                        externalEnglishSubjects: [
                            SubjectScore(subject: "英検準1級", score: "25点")
                        ],
                        externalEnglishMemo: "英検準1級は個別試験の英語へ25点加点。加点後も150点を上限とする。",
                        commonTestBorderRate: "71",
                        minimumPassingScore: "846",
                        acceptanceRatio: "3.6倍",
                        capacity: "42名",
                        memo: "候補から外したため大学ごと非表示。数学の記述対策が必要。",
                        checklistItems: sampleChecklist(
                            completedTitles: ["募集要項を確認", "出願サイト登録", "活動実績書を先生に確認"],
                            customTitles: ["活動実績書を先生に確認", "PC利用可否を確認"]
                        ),
                        customScheduleItems: [
                            sampleSchedule("活動実績書の校内確認", year: 2027, month: 1, day: 20),
                            sampleSchedule("試験会場までの経路確認", year: 2027, month: 2, day: 15)
                        ]
                    )
                ]
            )
        ]
    }
}

struct ExamOption: Identifiable, Hashable, Codable {
    var id = UUID()
    var isHidden = false
    var faculty: String
    var method: String
    var admissionCategory: ExamOptionCategory?
    var deviation: Double
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

    enum CodingKeys: String, CodingKey {
        case id
        case isHidden
        case faculty
        case method
        case admissionCategory
        case deviation
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

    var title: String {
        [faculty, method]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "・")
    }

    var resolvedAdmissionCategory: ExamOptionCategory {
        admissionCategory ?? .inferred(from: method)
    }

    init(
        id: UUID = UUID(),
        isHidden: Bool = false,
        faculty: String,
        method: String,
        admissionCategory: ExamOptionCategory? = nil,
        deviation: Double,
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
        applicationURL: String,
        subjects: [SubjectScore],
        commonTestSubjects: [SubjectScore],
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
        self.faculty = faculty
        self.method = method
        self.admissionCategory = admissionCategory
        self.deviation = deviation
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
        faculty = try container.decodeIfPresent(String.self, forKey: .faculty) ?? ""
        method = try container.decodeIfPresent(String.self, forKey: .method) ?? ""
        admissionCategory = try container.decodeIfPresent(ExamOptionCategory.self, forKey: .admissionCategory)
        deviation = try container.decodeIfPresent(Double.self, forKey: .deviation) ?? 60
        examDate = try container.decodeIfPresent(Date.self, forKey: .examDate)
        applicationStart = try container.decodeIfPresent(Date.self, forKey: .applicationStart)
        applicationEnd = try container.decodeIfPresent(Date.self, forKey: .applicationEnd)
        paymentDeadline = try container.decodeIfPresent(Date.self, forKey: .paymentDeadline)
        documentMailingDeadline = try container.decodeIfPresent(Date.self, forKey: .documentMailingDeadline)
        documentMailingDeadlineRule = documentMailingDeadline == nil
            ? nil
            : try container.decodeIfPresent(DocumentMailingDeadlineRule.self, forKey: .documentMailingDeadlineRule) ?? .mustArrive
        requiredDocuments = try container.decodeIfPresent(String.self, forKey: .requiredDocuments) ?? ""
        requiredDocumentItems = try container.decodeIfPresent([ExamRequiredDocument].self, forKey: .requiredDocumentItems)
            ?? ExamRequiredDocument.reconciled(from: requiredDocuments)
        resultDate = try container.decodeIfPresent(Date.self, forKey: .resultDate)
        admissionFeeDeadline = try container.decodeIfPresent(Date.self, forKey: .admissionFeeDeadline)
        tuitionDeadline = try container.decodeIfPresent(Date.self, forKey: .tuitionDeadline)
        guidelineURL = try container.decodeIfPresent(String.self, forKey: .guidelineURL) ?? ""
        applicationURL = try container.decodeIfPresent(String.self, forKey: .applicationURL) ?? ""
        subjects = try container.decodeIfPresent([SubjectScore].self, forKey: .subjects) ?? []
        commonTestSubjects = try container.decodeIfPresent([SubjectScore].self, forKey: .commonTestSubjects) ?? []
        externalEnglishSubjects = try container.decodeIfPresent([SubjectScore].self, forKey: .externalEnglishSubjects) ?? []
        externalEnglishMemo = try container.decodeIfPresent(String.self, forKey: .externalEnglishMemo) ?? ""
        commonTestBorderRate = try container.decodeIfPresent(String.self, forKey: .commonTestBorderRate) ?? ""
        minimumPassingScore = try container.decodeIfPresent(String.self, forKey: .minimumPassingScore) ?? ""
        acceptanceRatio = try container.decodeIfPresent(String.self, forKey: .acceptanceRatio) ?? ""
        capacity = try container.decodeIfPresent(String.self, forKey: .capacity) ?? ""
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
        checklistItems = try container.decodeIfPresent([ExamChecklistItem].self, forKey: .checklistItems) ?? ExamChecklistItem.defaultItems
        customScheduleItems = try container.decodeIfPresent([ExamCustomScheduleItem].self, forKey: .customScheduleItems) ?? []
    }

    static var blank: ExamOption {
        ExamOption(
            faculty: "",
            method: "",
            admissionCategory: .general,
            deviation: 60,
            examDate: nil,
            applicationStart: nil,
            applicationEnd: nil,
            paymentDeadline: nil,
            documentMailingDeadline: nil,
            documentMailingDeadlineRule: nil,
            requiredDocuments: "",
            resultDate: nil,
            admissionFeeDeadline: nil,
            tuitionDeadline: nil,
            guidelineURL: "",
            applicationURL: "",
            subjects: [],
            commonTestSubjects: [],
            externalEnglishSubjects: [],
            externalEnglishMemo: "",
            commonTestBorderRate: "",
            minimumPassingScore: "",
            acceptanceRatio: "",
            capacity: "",
            memo: "",
            checklistItems: ExamChecklistItem.defaultItems,
            customScheduleItems: []
        )
    }

    init(legacy school: ExamSchool) {
        id = school.id
        isHidden = school.isHidden
        faculty = school.faculty
        method = school.method
        admissionCategory = school.admissionCategory
        deviation = school.deviation
        examDate = school.examDate
        applicationStart = school.applicationStart
        applicationEnd = school.applicationEnd
        paymentDeadline = school.paymentDeadline
        documentMailingDeadline = school.documentMailingDeadline
        documentMailingDeadlineRule = school.documentMailingDeadlineRule
        requiredDocuments = school.requiredDocuments
        requiredDocumentItems = school.requiredDocumentItems
        resultDate = school.resultDate
        admissionFeeDeadline = school.admissionFeeDeadline
        tuitionDeadline = school.tuitionDeadline
        guidelineURL = school.guidelineURL
        applicationURL = school.applicationURL
        subjects = school.subjects
        commonTestSubjects = school.commonTestSubjects
        externalEnglishSubjects = school.externalEnglishSubjects
        externalEnglishMemo = school.externalEnglishMemo
        commonTestBorderRate = school.commonTestBorderRate
        minimumPassingScore = school.minimumPassingScore
        acceptanceRatio = school.acceptanceRatio
        capacity = school.capacity
        memo = school.memo
        checklistItems = school.checklistItems
        customScheduleItems = school.customScheduleItems
    }

    mutating func update(from school: ExamSchool) {
        faculty = school.faculty
        method = school.method
        admissionCategory = school.admissionCategory
        deviation = school.deviation
        examDate = school.examDate
        applicationStart = school.applicationStart
        applicationEnd = school.applicationEnd
        paymentDeadline = school.paymentDeadline
        documentMailingDeadline = school.documentMailingDeadline
        documentMailingDeadlineRule = school.documentMailingDeadlineRule
        requiredDocuments = school.requiredDocuments
        requiredDocumentItems = school.requiredDocumentItems
        resultDate = school.resultDate
        admissionFeeDeadline = school.admissionFeeDeadline
        tuitionDeadline = school.tuitionDeadline
        guidelineURL = school.guidelineURL
        applicationURL = school.applicationURL
        subjects = school.subjects
        commonTestSubjects = school.commonTestSubjects
        externalEnglishSubjects = school.externalEnglishSubjects
        externalEnglishMemo = school.externalEnglishMemo
        commonTestBorderRate = school.commonTestBorderRate
        minimumPassingScore = school.minimumPassingScore
        acceptanceRatio = school.acceptanceRatio
        capacity = school.capacity
        memo = school.memo
        checklistItems = school.checklistItems
        customScheduleItems = school.customScheduleItems
    }

    func joined(with university: UniversityChoice) -> ExamSchool {
        ExamSchool(
            id: id,
            isHidden: isHidden,
            universityID: university.id,
            name: university.name,
            nameKana: university.nameKana,
            faculty: faculty,
            method: method,
            admissionCategory: admissionCategory,
            universityType: university.universityType,
            deviation: deviation,
            color: university.color,
            examDate: examDate,
            applicationStart: applicationStart,
            applicationEnd: applicationEnd,
            paymentDeadline: paymentDeadline,
            documentMailingDeadline: documentMailingDeadline,
            documentMailingDeadlineRule: documentMailingDeadlineRule,
            requiredDocuments: requiredDocuments,
            requiredDocumentItems: requiredDocumentItems,
            resultDate: resultDate,
            admissionFeeDeadline: admissionFeeDeadline,
            tuitionDeadline: tuitionDeadline,
            guidelineURL: guidelineURL,
            passnaviURL: university.passnaviURL,
            applicationURL: applicationURL,
            subjects: subjects,
            commonTestSubjects: commonTestSubjects,
            externalEnglishSubjects: externalEnglishSubjects,
            externalEnglishMemo: externalEnglishMemo,
            commonTestBorderRate: commonTestBorderRate,
            minimumPassingScore: minimumPassingScore,
            acceptanceRatio: acceptanceRatio,
            capacity: capacity,
            memo: memo,
            checklistItems: checklistItems,
            customScheduleItems: customScheduleItems
        )
    }
}

enum MockExamJudgmentGrade: String, CaseIterable, Identifiable, Codable {
    case a = "A判定"
    case b = "B判定"
    case c = "C判定"
    case d = "D判定"
    case e = "E判定"

    var id: String { rawValue }
}

struct MockExamJudgment: Identifiable, Hashable, Codable {
    var id = UUID()
    var universityID: UUID
    var examOptionID: UUID
    var universityName: String
    var examOptionName: String
    var grade: MockExamJudgmentGrade
}

struct MockExamResult: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var date: Date
    var deviation: Double
    var isCommonTestMock: Bool
    var commonTestScoreRate: Double?
    var judgments: [MockExamJudgment]

    static func blank() -> MockExamResult {
        MockExamResult(
            name: "",
            date: Date(),
            deviation: 60,
            isCommonTestMock: false,
            commonTestScoreRate: nil,
            judgments: []
        )
    }

    static func samples(universities: [UniversityChoice]) -> [MockExamResult] {
        func judgment(
            universityName: String,
            method: String,
            faculty: String? = nil,
            grade: MockExamJudgmentGrade
        ) -> MockExamJudgment? {
            guard let university = universities.first(where: { $0.name == universityName }),
                  let option = university.examOptions.first(where: {
                      $0.method == method && (faculty == nil || $0.faculty == faculty)
                  }) else {
                return nil
            }
            return MockExamJudgment(
                universityID: university.id,
                examOptionID: option.id,
                universityName: university.name,
                examOptionName: option.title,
                grade: grade
            )
        }

        return [
            MockExamResult(
                name: "進研共通テスト模試",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 26)) ?? Date(),
                deviation: 56.9,
                isCommonTestMock: true,
                commonTestScoreRate: 66.0,
                judgments: [
                    judgment(universityName: "青葉大学", method: "一般A方式", grade: .d),
                    judgment(universityName: "桜丘大学", method: "共テ利用前期", grade: .c),
                    judgment(universityName: "東都大学", method: "前期日程", faculty: "文学部", grade: .e),
                    judgment(universityName: "北浜市立大学", method: "共テ単独6科目型", grade: .b)
                ].compactMap { $0 }
            ),
            MockExamResult(
                name: "駿台全国模試",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 7)) ?? Date(),
                deviation: 58.4,
                isCommonTestMock: false,
                commonTestScoreRate: nil,
                judgments: [
                    judgment(universityName: "青葉大学", method: "一般A方式", grade: .c),
                    judgment(universityName: "桜丘大学", method: "一般B方式", grade: .b),
                    judgment(universityName: "東都大学", method: "前期日程", faculty: "文学部", grade: .d),
                    judgment(universityName: "青葉大学", method: "英語外部利用方式", grade: .c)
                ].compactMap { $0 }
            ),
            MockExamResult(
                name: "全統記述模試",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 13)) ?? Date(),
                deviation: 60.7,
                isCommonTestMock: false,
                commonTestScoreRate: nil,
                judgments: [
                    judgment(universityName: "青葉大学", method: "一般A方式", grade: .b),
                    judgment(universityName: "桜丘大学", method: "一般B方式", grade: .a),
                    judgment(universityName: "東都大学", method: "前期日程", faculty: "文学部", grade: .c),
                    judgment(universityName: "北浜市立大学", method: "前期日程", grade: .b)
                ].compactMap { $0 }
            ),
            MockExamResult(
                name: "全統共通テスト模試",
                date: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18)) ?? Date(),
                deviation: 61.8,
                isCommonTestMock: true,
                commonTestScoreRate: 74.0,
                judgments: [
                    judgment(universityName: "青葉大学", method: "共通テスト利用3科目型", grade: .b),
                    judgment(universityName: "桜丘大学", method: "共テ利用前期", grade: .b),
                    judgment(universityName: "東都大学", method: "前期日程", faculty: "文学部", grade: .c),
                    judgment(universityName: "青葉大学", method: "英語外部利用方式", grade: .b),
                    judgment(universityName: "北浜市立大学", method: "共テ単独6科目型", grade: .a)
                ].compactMap { $0 }
            )
        ]
    }
}

enum MockExamResultPersistence {
    private static let key = "uniexam.mockExamResults.v1"
    private static let sampleVersionKey = "uniexam.mockExamResults.sampleVersion"
    private static let currentSampleVersion = 4

    static func load(universities: [UniversityChoice]) -> [MockExamResult] {
        if let data = UserDefaults.standard.data(forKey: key),
           let results = try? JSONDecoder().decode([MockExamResult].self, from: data) {
            let installedVersion = UserDefaults.standard.integer(forKey: sampleVersionKey)
            if installedVersion < currentSampleVersion {
                let refreshedResults: [MockExamResult]
                if isLegacySample(results) {
                    refreshedResults = MockExamResult.samples(universities: universities)
                } else {
                    refreshedResults = refreshBundledSampleJudgments(results, universities: universities)
                }
                save(refreshedResults)
                UserDefaults.standard.set(currentSampleVersion, forKey: sampleVersionKey)
                return refreshedResults
            }
            UserDefaults.standard.set(currentSampleVersion, forKey: sampleVersionKey)
            return results
        }

        let samples = MockExamResult.samples(universities: universities)
        save(samples)
        UserDefaults.standard.set(currentSampleVersion, forKey: sampleVersionKey)
        return samples
    }

    static func save(_ results: [MockExamResult]) {
        guard let data = try? JSONEncoder().encode(results) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func isLegacySample(_ results: [MockExamResult]) -> Bool {
        guard results.count == 1, let result = results.first else { return false }
        return result.name == "全統共通テスト模試"
            && abs(result.deviation - 61.8) < 0.001
            && result.isCommonTestMock
            && abs((result.commonTestScoreRate ?? 0) - 74.0) < 0.001
    }

    private static func refreshBundledSampleJudgments(
        _ results: [MockExamResult],
        universities: [UniversityChoice]
    ) -> [MockExamResult] {
        let currentSamples = MockExamResult.samples(universities: universities)
        let containsBundledSample = results.contains { result in
            currentSamples.contains { sample in
                sample.name == result.name
                    && Calendar.current.isDate(sample.date, inSameDayAs: result.date)
                    && abs(sample.deviation - result.deviation) < 0.001
            }
        }
        guard containsBundledSample else { return results }

        var refreshedResults = results.map { result in
            guard let sample = currentSamples.first(where: {
                $0.name == result.name
                    && Calendar.current.isDate($0.date, inSameDayAs: result.date)
                    && abs($0.deviation - result.deviation) < 0.001
            }) else {
                return result
            }

            var refreshed = result
            for judgment in sample.judgments where !refreshed.judgments.contains(where: {
                $0.examOptionID == judgment.examOptionID
            }) {
                refreshed.judgments.append(judgment)
            }
            return refreshed
        }

        for sample in currentSamples where !refreshedResults.contains(where: {
            $0.name == sample.name
                && Calendar.current.isDate($0.date, inSameDayAs: sample.date)
                && abs($0.deviation - sample.deviation) < 0.001
        }) {
            refreshedResults.append(sample)
        }

        return refreshedResults
    }
}

enum UniversityPersistence {
    private static let currentKey = "uniexam.universities.v2"
    private static let legacyKey = "uniexam.schools.v1"
    private static let sampleSnapshotKey = "uniexam.sampleUniversities.snapshot"
    private static let sampleVersionKey = "uniexam.sampleUniversities.version"

    // Bump this whenever UniversityChoice.samples changes so untouched sample data refreshes.
    private static let currentSampleVersion = 12

    static func load() -> [UniversityChoice] {
        if let data = UserDefaults.standard.data(forKey: currentKey) {
            guard let universities = try? JSONDecoder().decode([UniversityChoice].self, from: data) else {
                return []
            }
            return refreshSamplesIfNeeded(universities, currentData: data)
        }

        if let legacyData = UserDefaults.standard.data(forKey: legacyKey),
           let legacySchools = try? JSONDecoder().decode([ExamSchool].self, from: legacyData) {
            let universities = migrate(legacySchools)
            if isUntouchedLegacySample(universities) {
                return installCurrentSamples()
            }
            save(universities)
            return universities
        }

        return installCurrentSamples()
    }

    static func save(_ universities: [UniversityChoice]) {
        guard let data = try? JSONEncoder().encode(universities) else { return }
        UserDefaults.standard.set(data, forKey: currentKey)
    }

    static func migrate(_ schools: [ExamSchool]) -> [UniversityChoice] {
        var results: [UniversityChoice] = []

        for school in schools {
            let key = migrationKey(name: school.name, type: school.universityType)
            if let index = results.firstIndex(where: {
                migrationKey(name: $0.name, type: $0.universityType) == key
            }) {
                var option = ExamOption(legacy: school)
                if results[index].admissionsGuidelineURL.isEmpty, !option.guidelineURL.isEmpty {
                    results[index].admissionsGuidelineURL = option.guidelineURL
                }
                if results[index].applicationURL.isEmpty, !option.applicationURL.isEmpty {
                    results[index].applicationURL = option.applicationURL
                }
                option.guidelineURL = ""
                option.applicationURL = ""
                results[index].examOptions.append(option)
                if results[index].passnaviURL.isEmpty, !school.passnaviURL.isEmpty {
                    results[index].passnaviURL = school.passnaviURL
                }
            } else {
                results.append(
                    UniversityChoice(
                        name: school.name,
                        nameKana: school.nameKana,
                        universityType: school.universityType,
                        color: school.color,
                        officialAdmissionsURL: "",
                        passnaviURL: school.passnaviURL,
                        examOptions: [ExamOption(legacy: school)]
                    )
                )
            }
        }

        return results
    }

    private static func refreshSamplesIfNeeded(
        _ universities: [UniversityChoice],
        currentData: Data
    ) -> [UniversityChoice] {
        let defaults = UserDefaults.standard
        let installedVersion = defaults.integer(forKey: sampleVersionKey)
        guard installedVersion < currentSampleVersion else { return universities }

        let matchesStoredSample = defaults.data(forKey: sampleSnapshotKey) == currentData
        let matchesLegacySample = installedVersion == 0 && isUntouchedLegacySample(universities)
        guard matchesStoredSample || matchesLegacySample else {
            let mergedUniversities = mergeMissingSampleOptions(into: universities)
            save(mergedUniversities)
            defaults.set(currentSampleVersion, forKey: sampleVersionKey)
            return mergedUniversities
        }

        return installCurrentSamples()
    }

    private static func mergeMissingSampleOptions(
        into universities: [UniversityChoice]
    ) -> [UniversityChoice] {
        var merged = universities
        let sampleNames = Set(UniversityChoice.samples.map(\.name))
        let containsBundledUniversity = merged.contains {
            sampleNames.contains($0.name) && $0.officialAdmissionsURL.contains(".example")
        }
        guard containsBundledUniversity else { return universities }

        for sample in UniversityChoice.samples {
            if let index = merged.firstIndex(where: {
                $0.name == sample.name && $0.officialAdmissionsURL.contains(".example")
            }) {
                for option in sample.examOptions where !merged[index].examOptions.contains(where: {
                    $0.faculty == option.faculty && $0.method == option.method
                }) {
                    merged[index].examOptions.append(option)
                }
            } else {
                merged.append(sample)
            }
        }

        return merged
    }

    @discardableResult
    private static func installCurrentSamples() -> [UniversityChoice] {
        let samples = UniversityChoice.samples
        guard let data = try? JSONEncoder().encode(samples) else { return samples }
        let defaults = UserDefaults.standard
        defaults.set(data, forKey: currentKey)
        defaults.set(data, forKey: sampleSnapshotKey)
        defaults.set(currentSampleVersion, forKey: sampleVersionKey)
        return samples
    }

    private static func isUntouchedLegacySample(_ universities: [UniversityChoice]) -> Bool {
        guard universities.count == 3,
              universities.flatMap(\.examOptions).count == 3,
              Set(universities.map(\.name)) == Set(["青葉大学", "桜丘大学", "東都大学"]),
              universities.allSatisfy({ university in
                  university.preferenceRank == nil
                      && university.officialAdmissionsURL.isEmpty
                      && university.admissionsGuidelineURL.isEmpty
                      && university.customLinks.isEmpty
              }) else {
            return false
        }

        return Set(universities.flatMap(\.examOptions).map(\.method)) == Set(["一般A", "共テ利用", "一般B"])
    }

    private static func migrationKey(name: String, type: UniversityType) -> String {
        let normalizedName = name
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .lowercased(with: Locale(identifier: "ja_JP"))
        return "\(normalizedName)|\(type.rawValue)"
    }
}
