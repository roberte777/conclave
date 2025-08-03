import SwiftUI

struct GameListView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave

    var items = ["Item 1", "Item 2", "Item 3"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game List")
                .font(.title)
                .bold()
            ForEach(items, id: \.self) { item in
                Button(action: {
                    print("Tapped on \(item)")
                    // Replace with your desired action
                }) {
                    Text(item)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

//#Preview {
//    GameListView()
//}
