import Foundation
import Testing
@testable import IronPulse

struct WeekdayTests {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func mapeaCadaDiaDeCalendarioAlWeekdayCorrecto() {
        // Semana real: 2026-07-26 (domingo) a 2026-08-01 (sabado).
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 27)) == .monday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 28)) == .tuesday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 29)) == .wednesday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 30)) == .thursday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 31)) == .friday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 8, 1)) == .saturday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 26)) == .sunday)
    }
}
