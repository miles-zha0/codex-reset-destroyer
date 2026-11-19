import Foundation

@main struct Tests {
    static func main() {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
        for days in [5,6,7] { for weekday in 0..<7 { for (hour,minute,inside) in [(7,59,false),(8,0,true),(17,59,true),(18,0,false)] {
            let date = calendar.date(from:DateComponents(year:2026,month:11,day:16+weekday,hour:hour,minute:minute))!
            precondition(Schedule(days:days,start:480,end:1080).includes(date,calendar:calendar) == (weekday < days && inside))
        } } }
        let noon = Calendar.current.date(bySettingHour:12,minute:0,second:0,of:Date())!, schedule = Schedule(days:7,start:480,end:1080)
        for (used,week,hold,blocked,expected) in [(0,0,0.0,false,true),(1,0,0,false,false),(0,100,0,false,false),(0,0,noon.timeIntervalSince1970+1,false,false),(0,0,0,true,false)] {
            let data = Limits(primary:Window(usedPercent:used,windowDurationMins:300,resetsAt:nil),secondary:Window(usedPercent:week,windowDurationMins:nil,resetsAt:nil),planType:"plus",spendControlReached:blocked)
            precondition(eligible(data,state:Snapshot(hold:hold),date:noon,schedule:schedule)==expected)
        }; print("Schedule and eligibility tests passed.")
    }
}
