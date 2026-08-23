import ActivityKit
import WidgetKit
import SwiftUI

/// How long an event may run before it is considered abandoned.
///
/// MUST equal `kActiveEventTimeoutSeconds` in `AppDelegate.swift` and
/// `_timeoutMins * 60` in `lib/services/notification_service.dart`. Duplicated
/// here because MERWidget is a separate target from Runner and sharing a new
/// file means editing project.pbxproj; the project already duplicates
/// MERActivityAttributes.swift across the same boundary. A cross-language test
/// pins all three together.
///
/// Used ONLY to bound the timer. The timer previously ran to `startDate + 86400`
/// — twenty-four hours — which is why an abandoned event's lock screen read
/// "32:55" and climbing. A timer that outruns the timeout is asserting the app
/// still believes an event is running long after it has given up on it.
let merActiveEventTimeoutSeconds: TimeInterval = 30 * 60

struct MERLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MERActivityAttributes.self) { context in
            MERLockScreenView(context: context)
        } dynamicIsland: { context in
            // No statements before the DynamicIsland literal, and the start date
            // re-parsed at each use site rather than hoisted. Structurally
            // identical to the shape that already compiled: this target cannot be
            // type-checked from the Flutter toolchain, so novelty here is paid for
            // by the developer's build, not caught here.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image("MERIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .opacity(context.isStale ? 0.6 : 1)
                        Text(context.isStale ? "May still be running" : "Event in progress")
                            .font(.callout)
                            .foregroundColor(context.isStale ? .white.opacity(0.75) : .white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if #available(iOS 17.0, *) {
                        // Kept when stale. It still works, and it is the only way
                        // the user can close the event correctly — removing it
                        // would strand them with an event they cannot end.
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
                        if context.isStale {
                            // Static. A frozen number would be honest; a
                            // climbing one is not, and the app cannot vouch for
                            // either any more.
                            HStack(spacing: 4) {
                                Text("Started")
                                Text(startDate, style: .time)
                            }
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.white.opacity(0.65))
                        } else {
                            Text(timerInterval: startDate...(startDate + merActiveEventTimeoutSeconds),
                                 countsDown: false)
                                .font(.title3.monospacedDigit().bold())
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(context.isStale ? .secondary : .orange)
            } compactTrailing: {
                // Nothing when stale, deliberately. There is room for about five
                // characters here, and a frozen "30:00" is indistinguishable at
                // that size from a live one — so it would still be making the
                // claim this change exists to withdraw. The desaturated glyph
                // beside it carries the signal instead.
                if !context.isStale,
                   let startDate = ISO8601DateFormatter().date(from: context.state.startIso) {
                    Text(timerInterval: startDate...(startDate + merActiveEventTimeoutSeconds),
                         countsDown: false)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.orange)
                        .frame(maxWidth: 48)
                }
            } minimal: {
                // One glyph, so colour is the only channel available. Cheap and
                // honest: it stops looking active.
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(context.isStale ? .secondary : .orange)
            }
        }
    }
}

struct MERLockScreenView: View {
    let context: ActivityViewContext<MERActivityAttributes>

    /// True once `staleDate` has passed — set on the ActivityContent at request
    /// time in `AppDelegate.startLiveActivity`.
    ///
    /// This is the only signal available while the app is not running. Nothing
    /// in MER can end or update the activity from a killed process, so the
    /// display has to correct itself; `staleDate` is the mechanism iOS provides
    /// for exactly that, and before this it was set and then never read, which
    /// made it working and unobservable.
    private var isStale: Bool { context.isStale }

    private var startDate: Date? {
        ISO8601DateFormatter().date(from: context.state.startIso)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("MERIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .opacity(isStale ? 0.6 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("MER")
                    .font(.caption)
                    .foregroundColor(.white.opacity(isStale ? 0.55 : 0.7))

                // "Event in progress" is a claim the app cannot support once it
                // has stopped running. It says what is known instead: an event
                // was started, and whether it has ended is not something this
                // surface can answer.
                Text(isStale ? "Event may still be running" : "Event in progress")
                    .font(.headline)
                    .foregroundColor(.white.opacity(isStale ? 0.85 : 1))

                if let startDate {
                    if isStale {
                        HStack(spacing: 4) {
                            Text("Started")
                            Text(startDate, style: .time)
                        }
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.white.opacity(0.55))
                    } else {
                        Text(timerInterval: startDate...(startDate + merActiveEventTimeoutSeconds),
                             countsDown: false)
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.white.opacity(0.8))
                    }
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
        // Desaturated slate when stale, so it reads as wanting attention rather
        // than as a live recording. The brand navy is reserved for the state the
        // app can actually vouch for.
        .background(isStale
            ? Color(red: 0.17, green: 0.20, blue: 0.24)
            : Color(red: 0.05, green: 0.31, blue: 0.51))
    }
}
