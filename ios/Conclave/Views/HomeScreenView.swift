import SwiftUI

struct HomeScreenView: View {
    @Binding var screenPath: NavigationPath

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Conclave")
                    .font(.largeTitle)
                    .foregroundStyle(.primary)
                    .padding(75)
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        print("path before \(screenPath)")
                        screenPath.append(Screen.userSettings)
                        print("path after\(screenPath)")
                    }) {
                        Image(systemName: "person.circle")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.primary)
                            .padding()
                    }
                }
                Spacer()
            }

            VStack {
                Text("Login")
                    .font(.title)
                    .foregroundStyle(.primary)
                    .padding(10)
                Text("Offline Game")
                    .font(.title)
                    .foregroundStyle(.primary)
                    .onTapGesture {
                        screenPath.append(Screen.offlineGame)
                    }
            }
        }
    }
}

#Preview {
    HomeScreenView(screenPath: .constant(NavigationPath()))
}
