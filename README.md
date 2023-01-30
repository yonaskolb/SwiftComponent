<p align="center">
<img src="logo.png" height="244" />
</p>

# Swift Component

A SwiftUI architecture that bundles in world class tooling.

- Simple and easy to reason about data flow using composable pieces
- Built from the ground up with async await
- Upgraded and automatic Xcode previews with state editing, view modes, runnable tests and more
- Write declaritive tests next to your component and have them run on every change in Xcode preview, as well as on CI, or watch them playback visually in the preview
- In-App debug menu for components
- All discrete events that flow through the app can be tracked, logged, debugged or otherwise handled
- Use at the root of your application, just leaf views, or everything in between

### Parts
- Component**Model** which defines your domain and provides logic
- Component**View** which renders your model
- Component that brings the model and view together for previews and tests

### ComponentModel
**State**: This is your components state modeled as a struct or enum
**Action**: The actions users will take in the view, modeled as an enum
**Output**: Any output events your component may have, modeled as an enum. This is optional and defaults to `Never`
**Input** If connecting to another component that has output, those are listed here

### ComponentView
A `ComponentView` is a SwiftUI view, that has a single requirement of having a `model: ViewModel<ComponentModel>` property. The only things the view can do with the model are:

- access the read only state
- send it an `Action`
- bind to it's state with `model.binding(\.keyPath)`
- use `model.scope` to embed or present another ComponentView, requiring any `Output` of the component to be assigned an `Input`.

### Component
A `Component` brings together a model and view. It builds on SwiftUI's PreviewProvider. Instead of providing views, you define states which automatically show views with those states in the preview.

Additionally, tests can be defined which can then be run right in Xcode previews. And no, they won't be included in your app bundle.