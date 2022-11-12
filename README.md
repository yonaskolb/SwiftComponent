<p align="center">
<img src="logo.png" height="244" />
</p>

# Swift Component

A SwiftUI architecture that makes feature development fun and easy.

- Simple and easy to reason about data flow using composable pieces
- Built from the ground up with async await
- Xcode previews on steroids with state editing, view modes, runnable tests and more
- In-App debug menu for components
- All discrete events that flow through the app can be tracked, logged, or otherwise handled
- Write declaritive tests next to your component and have them run on every change in Xcode preview, as well as on CI, or watch them playback visually in the preview
- Use at the root of your application, just leaf views, or anything in between

### Parts
- Component**Model**
- Component**View**
- Component**Feature**

### ComponentModel
**State**: This is your components state modeled as a struct or enum
**Action**: The actions users will take in the view, modeled as an enum
**Output**: Any output events your component may have, modeled as an enum. This is optional and defaults to `Never`

### ComponentView
A `ComponentView` is a SwiftUI view, that has a single requirement of having a `model: ViewModel<ComponentModel>` property. The only things the view can with the model are:

- access the read only state
- send it an `Action`
- bind to it's state with `model.binding(\.keyPath)`
- use `model.scope` to embed or present another ComponentView, requiring any `Output` of the component to be assigned an `Action`.

### ComponentFeature
A `ComponentFeature` brings together a model and view. It builds on SwiftUI's PreviewProvider. Instead of providing views, you define states which automatically show views with those states in the preview.

Additionally, tests can be defined which can then be run right in Xcode previews. And no, they won't be included in your app bundle.


### Differences to TCA
How does this compare to the [Swift Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)?:

- Parents only have to handle children's outputs, and don't need to include all the actions
- Views only have access to real action not state mutation actions, or children actions
- "Reducers" (Components) can just kickoff async work and don't have to return an action
- Don't need task or binding actions
- Scoping into children only happens in the view and not also in the "Reducer" (Component)
- State mutations don't need to be actions, but are still individually tracked
- Don't need seperate Store and ViewStore, each child scope tracks Equatable changes using the power of Swift 5.7
- States modeled as enums can be simply switched over, with compiler support for matching all cases
- No need for all the different types of stores like IfLetStore and CaseLetStore
