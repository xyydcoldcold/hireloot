import SwiftUI

struct InterviewBoard: View {
    let store: JournalStore
    let edit: (Interview) -> Void

    var body: some View {
        let interviews = store.journal.interviews
        let active = interviews.filter { !$0.status.isClosed }.sorted { $0.scheduledAt < $1.scheduledAt }
        let history = interviews.filter { $0.status.isClosed }.sorted { $0.scheduledAt > $1.scheduledAt }
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("面试 Boss")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(active.count) 场进行中 · \(history.count) 场已归档")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button {
                        edit(Interview())
                    } label: {
                        Label("添加面试", systemImage: "plus")
                    }
                    .buttonStyle(ActionButton())
                }

                if interviews.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "flag")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(Theme.moss)
                            .accessibilityHidden(true)
                        Text("还没有面试记录")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 122)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).allowsHitTesting(false))
                }

                section("进行中", interviews: active)
                section("面试记录", interviews: history)
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func section(_ title: String, interviews: [Interview]) -> some View {
        if !interviews.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                ForEach(interviews) { interview in
                    interviewCard(interview)
                }
            }
        }
    }

    private func interviewCard(_ interview: Interview) -> some View {
        let status = interview.status
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 11) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.moss)
                    .frame(width: 34, height: 34)
                    .background(Theme.mint, in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(interview.company)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("\(interview.role) · \(interview.round)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 5)

                Menu {
                    ForEach(InterviewStatus.allCases) { choice in
                        Button {
                            var draft = interview
                            draft.status = choice
                            store.update { $0.saveInterview(draft) }
                        } label: {
                            if status == choice {
                                Label(choice.title, systemImage: "checkmark")
                            } else {
                                Text(choice.title)
                            }
                        }
                    }
                } label: {
                    Label(status.title, systemImage: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(status.foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(status.background, in: RoundedRectangle(cornerRadius: 6))
                        .fixedSize()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("更改 \(interview.company) 面试状态")
                .accessibilityValue(status.title)

                Button {
                    edit(interview)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 22, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TapButton())
                .help("编辑面试")
                .accessibilityLabel("编辑 \(interview.company) 面试")
            }

            Label(Theme.interviewDate(interview.scheduledAt), systemImage: "calendar")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            if !interview.notes.isEmpty {
                Text(interview.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.divider).allowsHitTesting(false))
    }
}

private extension InterviewStatus {
    var foreground: Color {
        switch self {
        case .scheduled, .passed: Theme.moss
        case .awaiting: Effort.project.foreground
        case .declined: Effort.networking.foreground
        case .cancelled: Theme.muted
        }
    }

    var background: Color {
        switch self {
        case .scheduled, .passed: Theme.mint
        case .awaiting: Effort.project.background
        case .declined: Effort.networking.background
        case .cancelled: Theme.paper
        }
    }
}

struct InterviewEditor: View {
    let isNew: Bool
    let save: (Interview) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Interview

    init(interview: Interview, isNew: Bool, save: @escaping (Interview) -> Bool) {
        _draft = State(initialValue: interview)
        self.isNew = isNew
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(isNew ? "添加面试 Boss" : "编辑面试 Boss")
                .font(.title2.bold())

            Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 12) {
                GridRow {
                    Text("公司")
                    TextField("公司名称", text: $draft.company)
                        .accessibilityLabel("公司")
                }
                GridRow {
                    Text("岗位")
                    TextField("岗位名称", text: $draft.role)
                        .accessibilityLabel("岗位")
                }
                GridRow {
                    Text("轮次")
                    TextField("例如 技术一面", text: $draft.round)
                        .accessibilityLabel("轮次")
                }
                GridRow {
                    Text("时间")
                    DatePicker("面试时间", selection: $draft.scheduledAt)
                        .labelsHidden()
                        .environment(\.locale, Theme.locale)
                }
                GridRow {
                    Text("状态")
                    Picker("面试状态", selection: $draft.status) {
                        ForEach(InterviewStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                GridRow(alignment: .top) {
                    Text("备注").padding(.top, 4)
                    TextEditor(text: $draft.notes)
                        .font(.body)
                        .frame(height: 70)
                        .padding(3)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.divider).allowsHitTesting(false))
                        .accessibilityLabel("面试备注")
                }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    if save(draft) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.moss)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.company.trimmed.isEmpty || draft.role.trimmed.isEmpty || draft.round.trimmed.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
