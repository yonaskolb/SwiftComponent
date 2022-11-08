//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 8/11/2022.
//

import SwiftUI

struct ComponentEditorView<Preview: ComponentFeature>: View {

    @State var fileContent: String = ""
    @State var editor = FeatureEditor(model: .init(state: "", handle: ""), view: .init(view: ""), preview: .init())

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
        let fileManager = FileManager.default

        guard let filePath = Preview.tests.first?.source.file.description else { return }
        guard let data = fileManager.contents(atPath: filePath) else { return }
        guard let string = String(data: data, encoding: .utf8) else { return }
        fileContent = string

    }

    var body: some View {
        VStack {
            ScrollView {
                Text(fileContent)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.5))
                    }
                    .padding()
            }
        }
        .task { setup() }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentEditorView<ExamplePreview>()
//            .previewDevice(.largestDevice)
    }
}
