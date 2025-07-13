import SwiftUI

struct FourPlayerGameView: View {
    @Binding var screenPath: NavigationPath

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    UserHealthView(.blue, isFlipped: true)
                    UserHealthView(.red, isFlipped: true)
                }
                HStack {
                    UserHealthView(.green, isFlipped: true)
                    UserHealthView(.yellow, isFlipped: true)
                }
            }
            .padding()

            Button(action: {
                screenPath = NavigationPath()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
                    .fontWeight(.bold)
                    .padding(10)
                    .background(Circle().fill(.background))
            }

        }
    }
}

#Preview {
    FourPlayerGameView(screenPath: .constant(NavigationPath()))
}
