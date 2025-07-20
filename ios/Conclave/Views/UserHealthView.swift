import SwiftUI

enum LifeOrientation: Double {
    case Up = 0
    case Left = 90
    case Right = 270
    case Down = 180
}

struct UserHealthView: View {
    @State var healthColor: Color
    @State var healthTotal: Int
    @State var lifeOrientation: LifeOrientation

    init(
        _ healthColor: SwiftUICore.Color,
        lifeOrientation: LifeOrientation = .Up
    ) {
        self.healthColor = healthColor
        self.healthTotal = 40
        self.lifeOrientation = lifeOrientation

    }

    struct HealthButtons: View {
        @Binding var givenHealthTotal: Int
        @Binding var givenLifeOrientation: LifeOrientation

        var body: some View {
            let flipLeftRight =
                (givenLifeOrientation == .Right
                    || givenLifeOrientation == .Down)
            let flipAngle: Double =
                (givenLifeOrientation == .Right
                    || givenLifeOrientation == .Left) ? 90 : 0
            ZStack {
                Color
                    .clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if flipLeftRight {
                            givenHealthTotal += 1
                        } else {
                            givenHealthTotal -= 1
                        }
                    }
                Image(systemName: flipLeftRight ? "plus" : "minus")
                    .rotationEffect(Angle(degrees: flipAngle))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .padding(10)
            }
            ZStack {
                Color
                    .clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if flipLeftRight {
                            givenHealthTotal -= 1
                        } else {
                            givenHealthTotal += 1
                        }
                    }
                Image(systemName: flipLeftRight ? "minus" : "plus")
                    .rotationEffect(Angle(degrees: flipAngle))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .padding(10)
            }
        }

    }

    var body: some View {
        GeometryReader { geo in
            ZStack {

                RoundedRectangle(cornerRadius: 15)
                    .fill(healthColor)

                Text("\(healthTotal)")
                    .foregroundStyle(.white)
                    .rotationEffect(Angle(degrees: lifeOrientation.rawValue))
                    .font(.system(size: geo.size.width * 0.3))
                    .minimumScaleFactor(0.1)

                if lifeOrientation == .Left || lifeOrientation == .Right {
                    VStack(spacing: 0) {
                        HealthButtons(
                            givenHealthTotal: $healthTotal,
                            givenLifeOrientation: $lifeOrientation
                        )
                    }
                } else {
                    HStack(spacing: 0) {
                        HealthButtons(
                            givenHealthTotal: $healthTotal,
                            givenLifeOrientation: $lifeOrientation
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    VStack {
        HStack {
            UserHealthView(.red, lifeOrientation: .Up)
        }
        HStack {
            UserHealthView(.yellow, lifeOrientation: .Left)
            UserHealthView(.blue, lifeOrientation: .Right)
        }
    }
    .padding()
}
