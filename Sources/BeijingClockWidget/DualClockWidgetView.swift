import Darwin
import SwiftUI
import WidgetKit
#if canImport(BeijingTimeCore)
import BeijingTimeCore
#endif

/// 一个系统小组件卡片里只有一个圆盘：外圈和内圈共用圆心。
/// 卡片圆角、边距和浅色/深色/降饱和由 WidgetKit 绘制，这里不另做一块底板。
struct DualClockWidgetView: View {
    var entry: DualClockEntry

    var body: some View {
        let zone = DualClockDial.resolvedInnerZone(identifier: entry.innerIdentifier)
        let pair = DualClockDial.pair(at: entry.date, innerZone: zone)
        let cycle = DualClockDial.cycle(containing: entry.date, innerZone: zone)
        VStack(alignment: .center, spacing: 8) {
            DualClockRing(pair: pair, day: cycle.displayedDay, labelStride: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            caption(pair: pair, cycle: cycle)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .containerBackground(.background, for: .widget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(pair: pair, day: cycle.displayedDay))
    }

    private func caption(pair: AbsolutePair, cycle: TwelveHourCycle) -> some View {
        let day = cycle.displayedDay
        return VStack(alignment: .center, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                timeColumn(
                    title: "北京",
                    time: DualClockDial.twelveHour(pair.beijing).text,
                    detail: "外圈 · \(pair.dayRelation == .today ? "今天" : pair.beijing.month.description + "月" + pair.beijing.day.description + "日")"
                )
                timeColumn(
                    title: DualClockDial.shortName(for: pair.inner.timeZoneIdentifier),
                    time: DualClockDial.twelveHour(pair.inner).text,
                    detail: pair.dayRelation.title
                )
            }
            centeredNote(DualClockDial.cycleHint(for: cycle.half))
            centeredNote(DualClockDial.instantOffsetPhrase(beijing: pair.beijing, inner: pair.inner))
            if day.distinctOffsets.count > 1 || !day.repeatedInnerClockHours.isEmpty {
                centeredNote(dayNote(day))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func centeredNote(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .lineLimit(3)
            .minimumScaleFactor(0.75)
    }

    private func timeColumn(title: String, time: String, detail: String) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(time)
                .font(.system(.title3, design: .default).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .modifier(AccentIfAvailable())
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func dayNote(_ day: BeijingDialDay) -> String {
        if day.distinctOffsets.count > 1 && !day.repeatedInnerClockHours.isEmpty {
            return "今天内圈时差会变，并有重复钟点。"
        }
        if day.distinctOffsets.count > 1 {
            return "今天内圈时差会变，不是全天同一个偏移。"
        }
        return "今天内圈有重复的钟点。"
    }

    private func accessibilityText(pair: AbsolutePair, day: BeijingDialDay) -> String {
        var text = "同一个圆盘，12 小时一圈。外圈北京 \(DualClockDial.twelveHour(pair.beijing).text)，内圈\(DualClockDial.shortName(for: pair.inner.timeZoneIdentifier)) \(DualClockDial.twelveHour(pair.inner).text)，\(pair.dayRelation.title)。\(DualClockDial.cycleHint(for: DualClockDial.halfDay(ofHour: pair.beijing.hour)))"
        if day.distinctOffsets.count > 1 {
            text += "今天的时差不是整天不变。"
        }
        return text
    }
}

private struct AccentIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.widgetAccentable()
        } else {
            content
        }
    }
}

struct DualClockRing: View {
    var pair: AbsolutePair
    var day: BeijingDialDay
    var labelStride: Int

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: side / 2)
            let radius = side / 2
            let outerRing = radius * 0.74
            let innerRing = radius * 0.52
            let quietInk = Color.secondary.opacity(0.45)
            strokeCircle(center: center, radius: outerRing, in: &context, color: Color.secondary, width: 1)
            strokeCircle(center: center, radius: innerRing, in: &context, color: quietInk, width: 1)

            for spoke in day.spokes {
                let emphasized = spoke.beijingHour == DualClockDial.emphasizedBeijingHour
                let eveningEight = spoke.beijingHour == 20
                let showLabel = emphasized || spoke.beijingHour.isMultiple(of: labelStride)
                let tickColor = emphasized ? Color.primary : quietInk
                let tickWidth: CGFloat = emphasized ? 2.5 : 1
                var ray = Path()
                ray.move(to: point(center: center, radius: innerRing - 2, angle: spoke.angleDegrees))
                ray.addLine(to: point(center: center, radius: outerRing + (emphasized ? 8 : 5), angle: spoke.angleDegrees))
                context.stroke(ray, with: .color(tickColor), style: StrokeStyle(lineWidth: tickWidth, lineCap: .round))
                if emphasized {
                    let end = point(center: center, radius: outerRing + 8, angle: spoke.angleDegrees)
                    let marker = CGRect(x: end.x - 3.5, y: end.y - 3.5, width: 7, height: 7)
                    context.fill(Path(roundedRect: marker, cornerRadius: 1.5), with: .color(Color.primary))
                }
                if showLabel {
                    draw(
                        DualClockDial.outerMark(beijingHour: spoke.beijingHour),
                        at: point(center: center, radius: radius * 0.94, angle: spoke.angleDegrees),
                        in: &context,
                        size: emphasized || eveningEight ? 12 : 11,
                        weight: emphasized || eveningEight ? .semibold : .regular,
                        color: Color.primary
                    )
                    let repeated = day.repeatedInnerClockHours.contains {
                        $0.year == spoke.inner.year && $0.month == spoke.inner.month
                            && $0.day == spoke.inner.day && $0.hour == spoke.inner.hour
                    }
                    draw(
                        "\(DualClockDial.twelveHour(spoke.inner).hourOnFace)" + (repeated ? "重" : ""),
                        at: point(center: center, radius: (innerRing + outerRing) / 2, angle: spoke.angleDegrees),
                        in: &context,
                        size: 9,
                        weight: .regular,
                        color: Color.secondary
                    )
                }
            }

            let nowAngle = DualClockDial.angleDegrees(
                hour: pair.beijing.hour,
                minute: pair.beijing.minute,
                second: pair.beijing.second
            )
            let now = point(center: center, radius: outerRing - 4, angle: nowAngle)
            var hand = Path()
            hand.move(to: center)
            hand.addLine(to: now)
            context.stroke(hand, with: .color(Color.primary), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)),
                with: .color(Color.primary)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: now.x - 3, y: now.y - 3, width: 6, height: 6)),
                with: .color(Color.primary)
            )
        }
        .accessibilityLabel("一个圆盘上的内外同心环。正上方是 12。早 8 和晚 8 在同一个角度，要看这一圈是上午还是下午。")
    }

    private func strokeCircle(
        center: CGPoint,
        radius: CGFloat,
        in context: inout GraphicsContext,
        color: Color,
        width: CGFloat
    ) {
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = Angle.degrees(angle).radians
        return CGPoint(
            x: center.x + CGFloat(sin(radians)) * radius,
            y: center.y - CGFloat(cos(radians)) * radius
        )
    }

    private func draw(
        _ text: String,
        at point: CGPoint,
        in context: inout GraphicsContext,
        size: CGFloat,
        weight: Font.Weight,
        color: Color
    ) {
        let resolved = context.resolve(
            Text(text).font(.system(size: size, weight: weight, design: .default)).foregroundStyle(color)
        )
        context.draw(resolved, at: point, anchor: .center)
    }
}
