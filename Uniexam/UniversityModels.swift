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
                        minimumPassingScore: "365/500点",
                        acceptanceRatio: "2.3倍",
                        capacity: "35名",
                        memo: "共通テストの自己採点後に出願内容を最終確認"
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
                        minimumPassingScore: "378/500点",
                        acceptanceRatio: "2.6倍",
                        capacity: "80名",
                        memo: "英語の配点が高いので直前期に重点確認"
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
                        minimumPassingScore: "352/500点",
                        acceptanceRatio: "3.1倍",
                        capacity: "45名",
                        memo: "英語はリーディングとリスニングを合算"
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
                        minimumPassingScore: "742/1400点",
                        acceptanceRatio: "2.1倍",
                        capacity: "60名",
                        memo: "合格発表から入学金締切までが短い"
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
                        minimumPassingScore: "718/1300点",
                        acceptanceRatio: "2.8倍",
                        capacity: "40名",
                        memo: "面接用に活動報告書の内容を整理しておく"
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

enum UniversityPersistence {
    private static let currentKey = "uniexam.universities.v2"
    private static let legacyKey = "uniexam.schools.v1"
    private static let sampleSnapshotKey = "uniexam.sampleUniversities.snapshot"
    private static let sampleVersionKey = "uniexam.sampleUniversities.version"

    // Bump this whenever UniversityChoice.samples changes so untouched sample data refreshes.
    private static let currentSampleVersion = 9

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
            defaults.set(currentSampleVersion, forKey: sampleVersionKey)
            return universities
        }

        return installCurrentSamples()
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
