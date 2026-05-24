import WidgetKit
import SwiftUI

@main
struct ZiitoWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZiitoWidget()
        ZiitoFocusLiveActivity()
    }
}
