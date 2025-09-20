import Clerk
import SwiftUI

struct HomeScreenView: View {
    @Environment(\.clerk) private var clerk
    @Binding var screenPath: NavigationPath
    @State private var authIsPresented = false

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
                Spacer()
                if clerk.user != nil {
                    UserButton()
                        .frame(width: 36, height: 36)
                } else {
                    HStack {
                        Button(action: {
                            authIsPresented = true
                        }) {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.primary)
                                .padding()
                        }
                    }
                }
            }

            VStack {
                Text("Online Game")
                    .font(.title)
                    .foregroundStyle(.primary)
                    .onTapGesture {
                        if clerk.user != nil {
                            screenPath.append(Screen.gameList)
                        } else {
                            authIsPresented = true
                        }
                    }
                    .padding(10)
                Text("Offline Game")
                    .font(.title)
                    .foregroundStyle(.primary)
                    .onTapGesture {
                        screenPath.append(Screen.offlineGame)
                    }
            }
        }
        .sheet(isPresented: $authIsPresented) {
            AuthView()
        }
    }
}

#Preview {
    HomeScreenView(screenPath: .constant(NavigationPath()))
}
