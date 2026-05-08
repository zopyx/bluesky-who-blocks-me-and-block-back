import Foundation

enum LoadableState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(AppError)

    var value: Value? {
        if case .loaded(let v) = self { v } else { nil }
    }

    var isLoaded: Bool {
        if case .loaded = self { true } else { false }
    }

    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    var error: AppError? {
        if case .failed(let e) = self { e } else { nil }
    }

    mutating func startLoading() {
        self = .loading
    }

    mutating func succeed(with value: Value) {
        self = .loaded(value)
    }

    mutating func fail(with error: AppError) {
        self = .failed(error)
    }
}
