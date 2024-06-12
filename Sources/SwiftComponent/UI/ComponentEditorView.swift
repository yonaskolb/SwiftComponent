import SwiftUI
import SwiftSyntax

/**
 TODO: syntax highlighting
 TODO: proper editor with at least auto indent
 TODO: finer grained code blocks
 **/
struct ComponentEditorView<ComponentType: Component>: View {

    @State var initialFileContent: String = ""
    @State var fileContent: String = ""
    @State var modelBlock: Codeblock?
    @State var viewBlock: Codeblock?
    @State var componentBlock: Codeblock?
    @State var output = ""
    @State var showFile = false
    @State var hasChanges = false
    @State var sourceFileSyntax: SourceFileSyntax?
    let fileManager = FileManager.default

    func setup() {

        guard let source = ComponentType.readSource() else { return }
        fileContent = source
        initialFileContent = source

        let parser = CodeParser(source: source)
        sourceFileSyntax = parser.syntax
        modelBlock = parser.modelSource
        viewBlock = parser.viewSource
        componentBlock = parser.componentSource

        //        output = parser.syntax.debugDescription(includeChildren: true)
    }

    func save() {
        guard var sourceFileSyntax else { return }
        
        let blocks = [
            modelBlock,
            viewBlock,
            componentBlock,
        ]
            .compactMap { $0 }
            .filter(\.changed)

        let rewriter = CodeRewriter(blocks: blocks)
        sourceFileSyntax = rewriter.rewrite(sourceFileSyntax)
        let sourceCode = sourceFileSyntax.description

        ComponentType.writeSource(sourceCode)
        
        hasChanges = false
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading) {
                editors
                if output != "" {
                    ScrollView {
                        Text(output)
                    }
                }
            }
            .padding()
            .padding(.top)
            if hasChanges {
                Button(action: save) {
                    Text("Save")
                        .font(.title)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
        .task { setup() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
        VStack(alignment: .leading, spacing: 24) {
            editor("Model", $modelBlock)
            editor("View", $viewBlock)
            editor("Component", $componentBlock)
        }
    }

    @ViewBuilder
    func editor(_ title: String, _ string: Binding<Codeblock?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .bold()
                .font(.title2)
                .padding(.horizontal, 8)
            TextEditor(text: Binding(
                get: { string.wrappedValue?.source ?? ""},
                set: {
                    string.wrappedValue?.source = $0
                    hasChanges = true
                }))
            .autocorrectionDisabled(true)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .colorScheme(.dark)
            .padding(.horizontal, 4)
            .background(.black)
            .cornerRadius(12)
        }
    }
}

struct ComponentEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentEditorView<ExampleComponent>()
            .largePreview()
    }
}
