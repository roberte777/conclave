import SwiftUI

struct OnlineGameView: View {
    @Binding var screenPath: NavigationPath
    var body: some View {
        Text( /*@START_MENU_TOKEN@*/"Hello, World!" /*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    OnlineGameView(screenPath: .constant(NavigationPath()))
}
