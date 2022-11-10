//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 8/11/2022.
//

import SwiftUI
import Parsing

struct FeatureEditorView<Preview: ComponentFeature>: View {

    @State var initialFileContent: String = ""
    @State var fileContent: String = ""
    @State var editor = FeatureEditor(model: .init(state: "", handle: ""), view: .init(view: ""), preview: .init())
    @State var output = ""
    @State var filePath = ""
    @AppStorage("preview.editor.showFile") var showFile = false
    let fileManager = FileManager.default

    var hasChanges: Bool { initialFileContent != fileContent }

    struct FeatureEditor {
        var model: ComponentModelEditor
        var view: ViewEditor
        var preview: PreviewEditor
    }

    struct ViewEditor {
        var view: String
    }

    struct PreviewEditor {
        var states: String?
        var tests: String?
    }

    struct ComponentModelEditor {
        var state: String
        var input: String?
        var output: String?
        var appear: String?
        var handle: String
    }

    func setup() {


        guard let filePath = Preview.tests.first?.source.file.description else { return }
        self.filePath = filePath
        guard let data = fileManager.contents(atPath: filePath) else { return }
        guard let string = String(data: data, encoding: .utf8) else { return }
        fileContent = string
        initialFileContent = string
        func scopeParser(prefix: String) -> some Parser {
            Parse {
                Skip {
                    PrefixUpTo(prefix)
                    PrefixThrough("{\n")
                }
                PrefixUpTo("}")
                Skip {
                    Rest()
                }
            }
            .map(String.init)
        }

        let stateParser = Parse {
            Skip {
                PrefixUpTo("State:")
                PrefixThrough("{\n")
            }
            PrefixUpTo("}").map(String.init)
        }

        let handlerParser = Parse {
            Skip {
                PrefixUpTo("switch input")
                PrefixThrough("{\n")
            }
            PrefixUpTo("}").map(String.init)
        }

//        let stateParser = scopeParser(prefix: "State:")
//        let handlerParser = scopeParser(prefix: "switch input")

        let modelParser = Parse {
            stateParser
            handlerParser
            Skip {
                Rest()
            }
        }
        do {
            let feature = try modelParser.parse(string)

            func removePadding(_ string: String) -> String {

                let lines = string.components(separatedBy: "\n")
                guard let firstLine = lines.first else { return string }
                var paddingIndex: Int?
                for (index, char) in firstLine.enumerated() {
                    if char != "\t" && char != " " {
                        paddingIndex = index
                        break
                    }
                }
                guard var index = paddingIndex else { return string }
                return lines
                    .map { line in
                        var line = line
                        if line.count > index {
                            line.removeSubrange(line.startIndex ..< line.index(line.startIndex, offsetBy: index))
                        }
                        return line
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            editor.model.state = removePadding(feature.0)
            editor.model.handle = removePadding(feature.1)
        } catch {
            output = String(describing: error)
        }
    }

    func save() {
        guard let data = fileContent.data(using: .utf8) else { return }
        fileManager.createFile(atPath: filePath, contents: data)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading) {
                    if output != "" {
                        Text(output)
                    }
                    editors

                    DisclosureGroup(isExpanded: $showFile) {
                        wholeFile
                    } label: {
                        HStack {
                            Image(systemName: "swift")
                                .foregroundColor(.orange)
                            Text(filePath.components(separatedBy: "/").last ?? "")
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        .font(.headline)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            if hasChanges {
                Button(action: save) {
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task { setup() }
    }

    var wholeFile: some View {
        TextEditor(text: $fileContent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.5))
            }
    }

    var editors: some View {
        VStack(alignment: .leading) {
            Text("State")
                .bold()
            editor($editor.model.state)
            Text("Handle Input")
                .bold()
            editor($editor.model.handle)
        }
    }

    @ViewBuilder
    func editor(_ binding: Binding<String>) -> some View {
        if #available(iOS 16.0, *) {
            TextEditor(text: binding)
                .lineLimit(2...10)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.5))
                }
        } else {
            TextEditor(text: binding)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.5))
                }
        }
    }
}

struct ComponentEditorView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureEditorView<ExamplePreview>()
            .previewDevice(.largestDevice)
    }
}
