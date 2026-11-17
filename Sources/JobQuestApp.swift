import SwiftUI

@main
struct JobQuestApp: App {
    @StateObject private var store = JournalStore()

    var body: some Scene {
        Window("求职冒险", id: "journal") {
            JournalWindow(store: store)
                .frame(minWidth: 890, minHeight: 620)
        }
        .defaultSize(width: 1080, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

enum JournalTab: String, CaseIterable, Identifiable {
    case quests, interviews

    var id: String { rawValue }
    var title: String { self == .quests ? "每日待办" : "面试 Boss" }
    var icon: String { self == .quests ? "list.bullet.rectangle" : "flag.fill" }
    var shortcut: KeyEquivalent { self == .quests ? "1" : "2" }
}

struct JournalWindow: View {
    @ObservedObject var store: JournalStore
    @State private var tab: JournalTab = .quests
    @State private var questToEdit: Quest?
    @State private var interviewToEdit: Interview?
    @State private var now = Date.now
    @State private var questTitle = ""
    @State private var questEffort: Effort?
    @State private var expandedDays = Set<Date>()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.divider).frame(height: 1)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        if let error = store.loadError {
                            loadFailure(error)
                        }
                        Group {
                            switch tab {
                            case .quests:
                                QuestBoard(
                                    store: store,
                                    now: now,
                                    title: $questTitle,
                                    effort: $questEffort,
                                    expanded: $expandedDays
                                ) { questToEdit = $0 }
                            case .interviews:
                                InterviewBoard(store: store) { interviewToEdit = $0 }
                            }
                        }
                        .disabled(store.loadError != nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    ProgressPanel(journal: store.journal, now: now) {
                        tab = .interviews
                        interviewToEdit = $0
                    }
                    .frame(width: max(330, min(408, geometry.size.width * 0.36)))
                }
            }
        }
        .background(Theme.paper)
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDate() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDate() }
        }
        .sheet(item: $questToEdit) { quest in
            QuestEditor(quest: quest) { title, effort in
                store.update { $0.editQuest(quest.id, title: title, effort: effort) }
            }
            .journalSaveAlert(error: $store.saveError)
        }
        .sheet(item: $interviewToEdit) { interview in
            InterviewEditor(interview: interview, isNew: !store.journal.interviews.contains { $0.id == interview.id }) { draft in
                store.update { $0.saveInterview(draft) }
            }
            .journalSaveAlert(error: $store.saveError)
        }
        .journalSaveAlert(
            error: $store.saveError,
            enabled: questToEdit == nil && interviewToEdit == nil
        )
    }

    private var header: some View {
        HStack(spacing: 13) {
            Image(systemName: "map.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.glow)
                .frame(width: 36, height: 36)
                .background(Theme.moss, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            Text("求职冒险")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)

            Spacer()

            HStack(spacing: 3) {
                ForEach(JournalTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        Label(item.title, systemImage: item.icon)
                            .font(.system(size: 13, weight: tab == item ? .semibold : .medium))
                            .foregroundStyle(tab == item ? Theme.ink : Theme.muted)
                            .padding(.horizontal, 13)
                            .frame(height: 31)
                            .background {
                                if tab == item {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Theme.surface)
                                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TapButton())
                    .keyboardShortcut(item.shortcut, modifiers: .command)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Theme.mint, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 27)
        .padding(.vertical, 13)
        .background(Theme.surface)
    }

    private func loadFailure(_ error: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("读取日记失败").font(.headline)
                Text(error).font(.caption).textSelection(.enabled)
            }
            Spacer()
            Button("重新读取", action: store.reload)
                .buttonStyle(ActionButton(primary: false))
        }
        .foregroundStyle(Theme.ink)
        .padding(12)
        .background(Color(hex: 0xF6E8CA), in: RoundedRectangle(cornerRadius: 10))
        .padding([.top, .horizontal], 22)
    }

    private func refreshDate() {
        now = .now
    }
}

extension View {
    func journalSaveAlert(error: Binding<String?>, enabled: Bool = true) -> some View {
        alert("保存失败", isPresented: Binding(
            get: { enabled && error.wrappedValue != nil },
            set: { if enabled && !$0 { error.wrappedValue = nil } }
        )) {
            Button("好", role: .cancel) { error.wrappedValue = nil }
        } message: {
            Text(error.wrappedValue ?? "")
        }
    }
}
