//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import SwiftUI
import SwiftPreview
import SwiftGUI

struct ComponentPreviewView<Preview: ComponentPreview>: View {

    @StateObject var viewModel = ViewModel<Preview.ComponentType>.init(state: Preview.states[0].state)

    var body: some View {
        HStack(spacing: 0) {
            Preview.ComponentViewType(model: viewModel)
                .preview()
                .padding()
            Divider()
            ComponentPreviewMenuView<Preview>(viewModel: viewModel)
        }
        .previewDevice(.largestDevice)
        .edgesIgnoringSafeArea(.all)
    }
}

struct ComponentPreviewMenuView<Preview: ComponentPreview>: View {

    @ObservedObject var viewModel: ViewModel<Preview.ComponentType>
    @State var testState: [String: TestState] = [:]
    @State var runningTests = false
    @AppStorage("autoRunTests") var autoRunTests = true
    @AppStorage("previewTests") var previewTests = true

    func getTestState(_ test: Test<Preview.ComponentType>) -> TestState {
        testState[test.name] ?? .notRun
    }

    enum TestState: Equatable {
        case notRun
        case running
        case failed([TestError])
        case success

        var errors: [TestError]? {
            switch self {
                case .failed(let errors):
                    if !errors.isEmpty { return errors}
                default: break
            }
            return nil
        }

        var color: Color {
            switch self {
                case .notRun: return .accentColor
                case .running: return .gray
                case .failed: return .red
                case .success: return .green
            }
        }
    }

    func runAllTests() {
        Task { @MainActor in
            for test in Preview.tests {
                await runTest(test)
            }
        }
    }

    func runTest(_ test: Test<Preview.ComponentType>) async {
        runningTests = true
        testState[test.name] = .running

        let viewModel: ViewModel<Preview.ComponentType>
        let delay: TimeInterval = previewTests ? 0.3 : 0
        if delay > 0 {
            viewModel = self.viewModel
        } else {
            viewModel = ViewModel(state: test.initialState)
        }
        let errors = await viewModel.runTest(test, delay: delay)

        if errors.isEmpty {
            testState[test.name] = .success
        } else {
            testState[test.name] = .failed(errors)
        }
        runningTests = false
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationView {
                form
                    .navigationTitle(Text("\(Preview.ComponentType.name) Component"))
                    .navigationBarTitleDisplayMode(.inline)
                    .frame(minHeight: 0)
            }
            Divider()
            NavigationView {
                SwiftView(value: viewModel.binding(\.self), config: Config(editing: true))
            }
            .navigationViewStyle(.stack)
        }
        .task {
            if autoRunTests {
                runAllTests()
            }
        }
        .navigationViewStyle(.stack)
    }

    var form: some View {
        Form {
//            Section(header:
//            Text(Preview.ComponentType.name + " Component")
//                .bold()
//                .foregroundColor(.primary)
//                .font(.title2)
//                .textCase(.none)
//                .padding(.top, 20)
//                .padding(.bottom, -12)
//            ) {}
            Section(header: Text("Settings")) {
                Toggle("Auto Run Tests", isOn: $autoRunTests)
                Toggle("Preview Tests", isOn: $previewTests)
            }
            Section(header: Text("States")) {
                ForEach(Preview.states, id: \.name) { state in
                    Button {
                        viewModel.state = state.state
                    } label: {
                        HStack {
                            Text(state.name)
                            Spacer()
                            Text(dumpLine(state.state))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if !Preview.tests.isEmpty {
                Section(header: testHeader) {
                    ForEach(Preview.tests, id: \.name) { test in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Task { @MainActor in
                                    await runTest(test)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    ZStack {
                                        ProgressView().hidden()
                                        switch getTestState(test) {
                                            case .running:
                                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                                            case .failed:
                                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                            case .success:
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                            case .notRun:
                                                Image(systemName: "circle")
                                        }
                                    }
                                    .foregroundColor(getTestState(test).color)
                                    Text(test.name)
                                        .foregroundColor(getTestState(test).color)
                                    Spacer()
                                    Image(systemName: "play.circle")
                                        .font(.title3)
                                }
                            }
                            if let errors = getTestState(test).errors {
                                Divider()
                                ForEach(errors) { error in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(error.error)
                                            .foregroundColor(.red)
                                        if let detail = error.errorDetail {
                                            Text(detail)
                                            //                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }

                    }
                    .disabled(runningTests)
                }
            }
        }
    }

    var testHeader: some View {
        HStack {
            Text("Tests")
            Spacer()
            Button(action: runAllTests) {
                Text("Run all")
            }
            .buttonStyle(.plain)
        }
    }
}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentPreviewView<ExamplePreview>()
    }
}
