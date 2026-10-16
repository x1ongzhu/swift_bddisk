import SwiftUI

// Explicit type alias avoids a State macro name collision in newer SDKs.
typealias ViewState<Value> = State<Value>
