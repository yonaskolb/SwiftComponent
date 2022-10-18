//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI
import SwiftGUI

#if DEBUG
public struct ComponentInfoView: View {

    let component: ComponentInfo
    @Binding var state: String?
    @State var render = UUID()

    var stateBinding: Binding<Any> {
        Binding<Any>(
            get: { component.state(name: state!).state },
            set: { component.applyState($0) }
        )
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("STATES")
                .foregroundColor(.gray)
                .font(.footnote)
                .padding(.horizontal)
                .padding(.top)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(component.states, id: \.self) { state in
                    Button(action: {
                        self.state = state
                        self.render = UUID()
                        withAnimation {
                            component.applyState(name: state)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 0) {
                            Divider()
                            HStack {
                                Text(state)
//                                    .color(self.state == state ? .white : .gray)
//                                    .midnight()
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider()
                        }

//                        .background(self.state == state ? Color.background : Color.systemBackground)
                    }
                }
            }
            if state != nil {
                VStack(alignment: .leading, spacing: 0) {
                    Text("STATE EDITOR")
                        .foregroundColor(.gray)
                        .font(.footnote)
                        .padding(.horizontal)
                        .padding(.bottom)
                    Divider()
                    NavigationView {
                        SwiftView(value: stateBinding, config: Config(editing: true))
                    }
                    .animation(nil)
                    .id(state!)
                    .navigationViewStyle(StackNavigationViewStyle())
                }
                .padding(.top, 40)
            }
        }
        .padding(.top)
    }
}
#endif
