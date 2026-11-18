import Darwin
import SwiftUI
import WidgetKit
#if canImport(BeijingTimeCore)
import BeijingTimeCore
#endif

struct DualClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var entry: DualClockEntry

    var body: some View {
        let zone = DualClockDial.resolvedInnerZone(identifier: entry.innerIdentifier)
        let pair = DualClockDial.pair(at: entry.date, innerZone: zone)
        let day = DualClockDial.beijingDay(containing: entry.date, innerZone: zone)
        let content = Group {
            if family == .systemMedium {
                HStack(alignment: .center, spacing: 8) {
                    DualClockRing(pair: pair, day: day, labelStride: 3)
                        .aspectRatio(1, contentMode: .fit)
                    caption(pair: pair, day: day)
                }
            } else {
                VStack(spacing: 6) {
                    DualClockRing(pair: pair, day: day, labelStride: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    caption(pair: pair, day: day)
                }
            }
        }
        content
            .containerBackground(for: .widget) {
                colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.96)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(pair: pair, day: day))
    }

    private func caption(pair: AbsolutePair, day: BeijingDialDay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("北京 \(DualClockDial.clockLabel(pair.beijing))")
                .font(.system(size: family == .systemMedium ? 16 : 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text("\(pair.inner.timeZoneIdentifier) \(DualClockDial.clockLabel(pair.inner))")
                .font(.system(size: family == .systemMedium ? 13 : 16, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("内圈日期：\(pair.dayRelation.title)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Text(DualClockDial.instantOffsetPhrase(beijing: pair.beijing, inner: pair.inner))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if day.distinctOffsets.count > 1 {
                Text("今天内圈偏移会变，其他钟点不是这个时差。")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !day.repeatedInnerClockHours.isEmpty {
                Text("今天有重复的钟点，环上会出现两次。")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accessibilityText(pair: AbsolutePair, day: BeijingDialDay) -> String {
        var text = "北京 \(DualClockDial.clockLabel(pair.beijing))，内圈 \(DualClockDial.clockLabel(pair.inner))，\(pair.dayRelation.title)。北京早8点在外圈有刻度标记。"
        if day.distinctOffsets.count > 1 {
            text += "今天的时差不是整天不变。"
        }
        return text
    }
}

struct DualClockRing: View {
    var pair: AbsolutePair
    var day: BeijingDialDay
    var labelStride: Int

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outerRadius = radius * 0.78
            let innerRadius = radius * 0.56
            let tickRadius = radius * 0.90
            var circle = Path()
            circle.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
            context.stroke(circle, with: .color(.primary.opacity(0.35)), lineWidth: 1)

            for spoke in day.spokes {
                let emphasized = spoke.beijingHour == DualClockDial.emphasizedBeijingHour
                let showLabel = emphasized || spoke.beijingHour % labelStride == 0
                let outerPoint = point(center: center, radius: outerRadius, angle: spoke.angleDegrees)
                let tickEnd = point(center: center, radius: tickRadius, angle: spoke.angleDegrees)
                var tick = Path()
                tick.move(to: outerPoint)
                tick.addLine(to: tickEnd)
                context.stroke(
                    tick,
                    with: .color(.primary),
                    style: StrokeStyle(lineWidth: emphasized ? 3 : 1, lineCap: .round)
                )
                if emphasized {
                    let marker = CGRect(x: tickEnd.x - 4, y: tickEnd.y - 4, width: 8, height: 8)
                    context.fill(Path(roundedRect: marker, cornerRadius: 1), with: .color(.primary))
                }
                if showLabel {
                    let outerText = emphasized ? DualClockDial.emphasizedMark : String(format: "%02d", spoke.beijingHour)
                    draw(
                        outerText,
                        at: point(center: center, radius: radius * 0.98, angle: spoke.angleDegrees),
                        in: &context,
                        size: emphasized ? 11 : 9,
                        weight: emphasized ? .bold : .regular
                    )
                    let repeated = day.repeatedInnerClockHours.contains {
                        $0.year == spoke.inner.year && $0.month == spoke.inner.month
                            && $0.day == spoke.inner.day && $0.hour == spoke.inner.hour
                    }
                    let innerText = DualClockDial.clockLabel(spoke.inner) + (repeated ? "重" : "")
                    draw(
                        innerText,
                        at: point(center: center, radius: innerRadius, angle: spoke.angleDegrees),
                        in: &context,
                        size: 8,
                        weight: .regular
                    )
                }
            }

            let now = point(
                center: center,
                radius: radius * 0.68,
                angle: DualClockDial.angleDegrees(
                    hour: pair.beijing.hour,
                    minute: pair.beijing.minute,
                    second: pair.beijing.second
                )
            )
            var hand = Path()
            hand.move(to: center)
            hand.addLine(to: now)
            context.stroke(hand, with: .color(.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: now.x - 3.5, y: now.y - 3.5, width: 7, height: 7)), with: .color(.primary))
        }
        .accessibilityLabel("二十四小时环。正上方是北京零点，顺时针。北京早8点有方块刻度。")
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
        weight: Font.Weight
    ) {
        let resolved = context.resolve(
            Text(text).font(.system(size: size, weight: weight)).foregroundStyle(.primary)
        )
        context.draw(resolved, at: point, anchor: .center)
    }
}
