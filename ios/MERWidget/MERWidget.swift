import WidgetKit
import SwiftUI

@main
struct MERWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        // Unconditional at the 16.2 deployment target. The gate here existed for
        // the 15.0-16.1 tier, where Live Activities did not exist at all.
        MERLiveActivity()
    }
}
