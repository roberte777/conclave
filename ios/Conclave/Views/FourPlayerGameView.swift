import SwiftUI

struct FourPlayerGameView: View {
    @Binding var screenPath: NavigationPath

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    //UserHealthView(.blue, lifeOrientation: .Left)
                    //UserHealthView(.red, lifeOrientation: .Right)
                }
                HStack {
                    //UserHealthView(.green, lifeOrientation: .Left)
                    //UserHealthView(.yellow, lifeOrientation: .Right)
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
