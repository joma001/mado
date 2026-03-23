import WidgetKit
import SwiftUI

@main
struct MadoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayEventsWidget()
        TodayTasksWidget()
        NextMeetingWidget()
        OverdueWidget()
    }
}
