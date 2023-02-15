<p align="center">
<img src="logo.png" height="244" />
</p>

# Swift Component

A SwiftUI architecture that bundles in world class tooling.

- **Composable**: Simple and easy to reason about data flow using composable pieces
- **Scalable**: A flexible component system based on progressive disclosure
- **Concurrancy**: Built from the ground up with async await
- **Xcode Previews**: Upgraded and automatic Xcode previews with state editing, view modes, runnable tests and more
- **Testing**: Write declaritive tests next to your component and have them run on every change in Xcode preview, as well as on CI, or watch them playback visually
- **Debugging**: In-App debug menu for components
- **Introspective**: A whole suite of discrete events that flow through the system and can be tracked, logged, debugged or otherwise handled
- **Flexible**: at the root of your application, just leaf views, or everything in between
- **Routing**: Routing between components for user based navigation and deeplinking

### Component Parts
- Component**Model** which defines your domain and provides logic
- Component**View** which renders your model
- Component that brings the model and view together for previews and tests

### ComponentModel
- **State**: This is your components state modeled as a struct or enum
- **Action**: An enumeration of all the actions users can take in the view
- **Output**: An enumeration of any output events your component may have
- **Input**: If connecting to another component that has output, those are enumerated here
- **Route**: An enumeration of all the models this can route to

### ComponentView
A `ComponentView` is a SwiftUI view, that has a single requirement of having a `model: ViewModel<ComponentModel>` property. The only things the view can do with the model are:

- access the read only state
- send it an Action
- bind to it's state for view controls
- compose with other ComponentViews

### Component
A `Component` brings together a model and view. It builds on SwiftUI's PreviewProvider. Instead of providing views, you define states which automatically show views with those states in the preview.

Additionally, tests can be defined which can then be run right in Xcode previews. And no, they won't be included in your app bundle.

### Testing
Tests are written on a Component right next to your model and view. They are a series of declaritive steps to perform on the model like sending an action, updating a binding, and setting dependencies. Test steps have a bunch of different assertions