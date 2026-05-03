import WidgetKit
import SwiftUI

@main
struct MERWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        if #available(iOS 16.2, *) {
            MERLiveActivity()
        }
    }
}
