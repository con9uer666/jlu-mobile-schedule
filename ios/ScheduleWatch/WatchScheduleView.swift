import SwiftUI

struct WatchScheduleView: View {
    @StateObject private var store = WatchConnectivityStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate = Date()
    @State private var showingDates = false
    @State private var followToday = true

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                if let schedule = store.schedule, schedule.semesterId != nil {
                    dayList(schedule, now: context.date)
                } else {
                    ContentUnavailableView {
                        Label("课程表", systemImage: "calendar")
                    } description: {
                        Text(store.schedule == nil ? store.status : "请先在 iPhone 上设置当前学期")
                    } actions: {
                        Button("重新同步") { store.refresh() }
                    }
                }
            }
            .navigationTitle("课程表")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.red)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if followToday { selectedDate = Date() }
                store.refresh()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "schedulewatch", url.host == "today" else { return }
            showingDates = false
            followToday = true
            selectedDate = Date()
            store.refresh()
        }
        .sheet(isPresented: $showingDates) {
            if let schedule = store.schedule {
                WatchDatePicker(schedule: schedule, selectedDate: selectedDate) { date in
                    selectedDate = date
                    followToday = schedule.calendar.isDateInToday(date)
                    showingDates = false
                }
            }
        }
    }

    private func dayList(_ schedule: WatchSchedule, now: Date) -> some View {
        let date = followToday ? now : selectedDate
        let courses = schedule.courses(on: date)
        let isToday = schedule.calendar.isDate(date, inSameDayAs: now)
        let nextID = isToday ? courses.first(where: {
            (schedule.time($0.startTime, on: date) ?? .distantPast) > now
        })?.id : nil
        return List {
            HStack(spacing: 0) {
                Button { moveDay(-1, schedule: schedule, from: date) } label: {
                    Image(systemName: "chevron.left").frame(width: 30, height: 36)
                }
                .disabled(!canMove(-1, schedule: schedule, from: date))
                .accessibilityLabel("前一天")
                Button { selectedDate = date; showingDates = true } label: {
                    VStack(spacing: 3) {
                        Text("\(schedule.calendar.component(.month, from: date))月\(schedule.calendar.component(.day, from: date))日")
                            .font(.headline)
                        Text(dayLabel(date, schedule: schedule))
                            .font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                }.accessibilityLabel("选择日期")
                Button { moveDay(1, schedule: schedule, from: date) } label: {
                    Image(systemName: "chevron.right").frame(width: 30, height: 36)
                }
                .disabled(!canMove(1, schedule: schedule, from: date))
                .accessibilityLabel("后一天")
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))

            if !isToday {
                Button("回到今天") { followToday = true; selectedDate = now }
                    .font(.footnote).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            if courses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar").font(.title2).foregroundStyle(.secondary)
                    Text("当天无课").font(.headline)
                    if schedule.day(on: date) == nil {
                        Text("当前日期不在本学期内").font(.caption2).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(courses) { course in
                    courseRow(course, schedule: schedule, date: date, now: now, nextID: nextID)
                }
            }
        }
        .listStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            moveDay(value.translation.width < 0 ? 1 : -1, schedule: schedule, from: date)
        })
    }

    private func courseRow(_ course: WatchCourse, schedule: WatchSchedule, date: Date, now: Date, nextID: String?) -> some View {
        let start = schedule.time(course.startTime, on: date) ?? .distantFuture
        let end = schedule.time(course.endTime, on: date) ?? .distantFuture
        let ended = end <= now
        let current = start <= now && now < end
        let next = course.id == nextID
        return HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(current ? Color.green : (next ? Color.red : Color.secondary))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 5) {
                if current || next {
                    Text(current ? "正在上课" : "下一节")
                        .font(.caption2).foregroundStyle(current ? .green : .red)
                }
                Text(course.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text("\(course.startTime)–\(course.endTime)")
                    .font(.subheadline).monospacedDigit()
                Label(course.location.isEmpty ? "教室未填写" : course.location, systemImage: "mappin")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .opacity(ended ? 0.45 : 1)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
    }

    private func dayLabel(_ date: Date, schedule: WatchSchedule) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekday = names[schedule.calendar.component(.weekday, from: date) - 1]
        if let day = schedule.day(on: date) { return "\(weekday) · 第\(day.week)周" }
        return weekday
    }
    private func canMove(_ amount: Int, schedule: WatchSchedule, from date: Date) -> Bool {
        guard let first = schedule.startDate.flatMap(schedule.date), let last = schedule.endDate.flatMap(schedule.date),
              let target = schedule.calendar.date(byAdding: .day, value: amount, to: date) else { return false }
        let today = schedule.calendar.startOfDay(for: Date())
        let day = schedule.calendar.startOfDay(for: target)
        return day >= min(first, today) && day <= max(last, today)
    }
    private func moveDay(_ amount: Int, schedule: WatchSchedule, from date: Date) {
        guard canMove(amount, schedule: schedule, from: date),
              let target = schedule.calendar.date(byAdding: .day, value: amount, to: date) else { return }
        selectedDate = target
        followToday = schedule.calendar.isDateInToday(target)
    }
}

// Explicit month/day selection works on watchOS and keeps every semester date
// reachable without swiping through a hundred pages.
struct WatchDatePicker: View {
    let schedule: WatchSchedule
    let selectedDate: Date
    let select: (Date) -> Void
    @State private var month = ""

    private var months: [String] { Array(Set(schedule.days.map { String($0.date.prefix(7)) })).sorted() }
    var body: some View {
        NavigationStack {
            List {
                Picker("月份", selection: $month) {
                    ForEach(months, id: \.self) { value in Text(value).tag(value) }
                }
                ForEach(schedule.days.filter { $0.date.hasPrefix(month) }) { day in
                    if let date = schedule.date(from: day.date) {
                        Button { select(date) } label: {
                            HStack {
                                Text(String(day.date.suffix(2)) + "日")
                                Spacer()
                                Text(day.courses.isEmpty ? "无课" : "\(day.courses.count)节课")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择日期")
            .onAppear {
                let current = String(schedule.dateKey(selectedDate).prefix(7))
                month = months.contains(current) ? current : (months.first ?? "")
            }
        }
    }
}
