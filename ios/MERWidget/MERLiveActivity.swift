import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct MERLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MERActivityAttributes.self) { context in
            MERLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image("MERIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Event in progress")
                            .font(.callout)
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if #available(iOS 17.0, *) {
                        Button(intent: EndMEREventIntent()) {
                            Label("End", systemImage: "stop.circle.fill")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let startDate = ISO8601DateFormatter().date(from: context.state.startIso) {
                        Text(timerInterval: startDate...(startDate + 86400), countsDown: false)
                            .font(.title3.monospacedDigit().bold())
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.orange)
            } compactTrailing: {
                if let startDate = ISO8601DateFormatter().date(from: context.state.startIso) {
                    Text(timerInterval: startDate...(startDate + 86400), countsDown: false)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.orange)
                        .frame(maxWidth: 48)
                }
            } minimal: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.orange)
            }
        }
    }
}

@available(iOS 16.2, *)
struct MERLockScreenView: View {
    let context: ActivityViewContext<MERActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("MERIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text("MER")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text("Event in progress")
                    .font(.headline)
                    .foregroundColor(.white)
                if let startDate = ISO8601DateFormatter().date(from: context.state.startIso) {
                    Text(timerInterval: startDate...(startDate + 86400), countsDown: false)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            if #available(iOS 17.0, *) {
                Button(intent: EndMEREventIntent()) {
                    Text("Event Ended")
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.65, green: 0.15, blue: 0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(red: 0.05, green: 0.31, blue: 0.51))
    }
}
