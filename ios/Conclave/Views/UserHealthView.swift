//
//  UserHealthView.swift
//  TestingPractice
//
//  Created by Colby Deason on 7/12/25.
//

import SwiftUI

struct UserHealthView: View {
    @State var isFlipped: Bool
    @State var healthTotal: Int
    @State var healthColor: Color
    
    init(_ healthColor: SwiftUICore.Color, isFlipped: Bool = false) {
        self.healthColor = healthColor
        self.isFlipped = isFlipped
        self.healthTotal = 40
    }
    
    struct HealthButtons: View{
        @Binding var givenHealthTotal: Int
        var body: some View{
            Color
                .clear
                .contentShape(Rectangle())
                .onTapGesture {
                    givenHealthTotal -= 1
                }
            Color
                .clear
                .contentShape(Rectangle())
                .onTapGesture {
                    givenHealthTotal += 1
                }
        }
        
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack{
                
                RoundedRectangle(cornerRadius: 15)
                    .fill(healthColor)
                
                Text("\(healthTotal)")
                    .foregroundStyle(.white)
                    .rotationEffect(isFlipped ? Angle(degrees: 90) : .zero)
                    .font(.system(size: geo.size.width * 0.3))
                    .minimumScaleFactor(0.1)
                
                if (isFlipped){
                    VStack(spacing: 0){
                        HealthButtons(givenHealthTotal: $healthTotal)
                    }
                }
                else{
                    HStack(spacing: 0){
                        HealthButtons(givenHealthTotal: $healthTotal)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    VStack{
        HStack{
            UserHealthView(.blue, isFlipped: true)
            UserHealthView(.red, isFlipped: true)
        }
        HStack{
            UserHealthView(.green, isFlipped: true)
            UserHealthView(.yellow, isFlipped: true)
        }
    }
    .padding()
}
