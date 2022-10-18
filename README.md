# SwiftComponent

An opinionated architecture that makes feature development easy.

### Parts
- Component
- ViewModel
- ComponentView
- Previews
- Test cases 

### Component types
- State
- Action
- Output

### Advantages over SCA
- Parents only have to handle children's outputs, and don't need to include all the actions
- Views only have access to action actions
- "Reducer" (Component) can just kickoff async work and don't have to return an action
- Don't need task or binding actions
- Scoping into children only happens in the view and not also in the "Reducer" (Component)
- State mutations don't need to be actions, but are still individually tracked
- Don't need seperate Store and ViewStore, each child scope tracks Equatable changes
- Enum state can be simply switched over, with compiler support for all cases
