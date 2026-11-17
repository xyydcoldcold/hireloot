import SwiftUI

struct ProgressPanel: View {
    let journal: Journal
    let now: Date
    let editInterview: (Interview) -> Void
    private static let camp = Bundle.main.url(forResource: "camp", withExtension: "png").flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        let byEffort = journal.experienceByEffort
        let total = Experience(points: byEffort.values.reduce(0, +), pointsPerLevel: 10)
        let scheduled = journal.interviews.filter { $0.status == .scheduled }
        let next = scheduled.filter { $0.scheduledAt >= now }.min { $0.scheduledAt < $1.scheduledAt }
        let overdue = scheduled.filter { $0.scheduledAt < now }.max { $0.scheduledAt < $1.scheduledAt }

        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                hero(total)

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("装备与成长")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.moon)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("每 5 XP 升一级")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.fog)
                    }

                    ForEach(Effort.allCases) { effort in
                        gearCard(effort, experience: Experience(points: byEffort[effort, default: 0], pointsPerLevel: 5))
                    }
                }

                nextBoss(next ?? overdue, title: next == nil ? "待更新的面试" : "下一场面试")
            }
            .padding(17)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.night)
    }

    private func hero(_ experience: Experience) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if let artwork = Self.camp {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityHidden(true)
                } else {
                    LinearGradient(colors: [Theme.panel, Theme.night], startPoint: .topTrailing, endPoint: .bottomLeading)
                }

                LinearGradient(
                    colors: [.black.opacity(0.77), .black.opacity(0.35), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 5) {
                    Text("冒险者")
                        .font(.system(size: 25, weight: .heavy))
                        .foregroundStyle(Theme.moon)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 7) {
                        Text("Lv. \(experience.level)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.night)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.glow, in: RoundedRectangle(cornerRadius: 4))
                        Text("\(experience.points) XP")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.moon)
                    }

                    let fraction = Double(experience.progress) / Double(experience.pointsPerLevel)
                    Capsule()
                        .fill(Theme.nightLine)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.glow)
                                .frame(width: 112 * fraction)
                        }
                        .frame(width: 112, height: 5)
                        .padding(.top, 3)
                        .accessibilityLabel("冒险者等级进度")
                        .accessibilityValue("\(experience.progress) / \(experience.pointsPerLevel) XP")
                }
                .padding(15)
            }
        }
        .frame(height: 155)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.nightLine).allowsHitTesting(false))
    }

    private func gearCard(_ effort: Effort, experience: Experience) -> some View {
        HStack(spacing: 10) {
            Image(systemName: effort.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(effort.gameColor)
                .frame(width: 33, height: 33)
                .background(effort.gameColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text(effort.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.moon)
                    .lineLimit(1)
                Text("\(effort.gear) · \(effort.equipment(at: experience.level))")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.fog)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Lv. \(experience.level)")
                        .foregroundStyle(effort.gameColor)
                    Text("\(experience.points) XP")
                        .foregroundStyle(Theme.fog)
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)

                HStack(spacing: 3) {
                    ForEach(0..<experience.pointsPerLevel, id: \.self) { point in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(point < experience.progress ? effort.gameColor : Theme.nightLine)
                            .frame(width: 12, height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.nightLine).allowsHitTesting(false))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func nextBoss(_ interview: Interview?, title: String) -> some View {
        if let interview {
            Button {
                editInterview(interview)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(Effort.project.gameColor)
                        .font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.fog)
                        Text("\(interview.company) · \(interview.round)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.moon)
                            .lineLimit(1)
                        Text(Theme.interviewDate(interview.scheduledAt))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.fog)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.fog)
                }
                .padding(10)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.nightLine).allowsHitTesting(false))
                .contentShape(Rectangle())
            }
            .buttonStyle(TapButton())
        }
    }
}
