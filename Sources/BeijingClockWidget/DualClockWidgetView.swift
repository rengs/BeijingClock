import Darwin
import SwiftUI
import WidgetKit
#if canImport(BeijingTimeCore)
import BeijingTimeCore
#endif

/// 一个系统小组件卡片里只有一个圆盘：外圈和内圈共用圆心。
/// 卡片圆角、边距和浅色/深色/降饱和由 WidgetKit 绘制，这里不另做一块底板。
struct DualClockWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: DualClockEntry

    var body: some View {
        let zone = DualClockDial.resolvedInnerZone(identifier: entry.innerIdentifier)
        let pair = DualClockDial.pair(at: entry.date, innerZone: zone)
        let day = DualClockDial.beijingDay(containing: entry.date, innerZone: zone)
        let stride = family == .systemExtraLarge ? 1 : 2
        VStack(alignment: .leading, spacing: 8) {
            DualClockRing(pair: pair, day: day, labelStride: stride)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            caption(pair: pair, day: day)
        }
        .containerBackground(.background, for: .widget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(pair: pair, day: day))
    }

    private func caption(pair: AbsolutePair, day: BeijingDialDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                timeColumn(title: "北京", time: DualClockDial.clockLabel(pair.beijing), detail: "外圈")
                timeColumn(
                    title: DualClockDial.shortName(for: pair.inner.timeZoneIdentifier),
                    time: DualClockDial.clockLabel(pair.inner),
                    detail: pair.dayRelation.title
                )
            }
            Text(DualClockDial.instantOffsetPhrase(beijing: pair.beijing, inner: pair.inner))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if day.distinctOffsets.count > 1 || !day.repeatedInnerClockHours.isEmpty {
                Text(dayNote(day))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func timeColumn(title: String, time: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(time)
                .font(.system(.title3, design: .default).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .modifier(AccentIfAvailable())
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
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
        var text = "同一个圆盘。外圈北京 \(DualClockDial.clockLabel(pair.beijing))，内圈\(DualClockDial.shortName(for: pair.inner.timeZoneIdentifier)) \(DualClockDial.clockLabel(pair.inner))，\(pair.dayRelation.title)。北京早8点有刻度标记。"
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
                        emphasized ? DualClockDial.emphasizedMark : String(format: "%02d", spoke.beijingHour),
                        at: point(center: center, radius: radius * 0.94, angle: spoke.angleDegrees),
                        in: &context,
                        size: emphasized ? 12 : 10,
                        weight: emphasized ? .semibold : .regular,
                        color: Color.primary
                    )
                    let repeated = day.repeatedInnerClockHours.contains {
                        $0.year == spoke.inner.year && $0.month == spoke.inner.month
                            && $0.day == spoke.inner.day && $0.hour == spoke.inner.hour
                    }
                    draw(
                        DualClockDial.clockLabel(spoke.inner) + (repeated ? "重" : ""),
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
        .accessibilityLabel("一个圆盘上的内外同心环。正上方是北京零点，顺时针。北京早8点有方块刻度。")
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
