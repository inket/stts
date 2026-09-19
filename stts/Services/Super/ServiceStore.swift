//
//  ServiceStore.swift
//  stts
//

import Foundation

protocol InitializableState {
    init()
}

extension Dictionary: InitializableState {}
extension Array: InitializableState {}

class ServiceStore<State: InitializableState>: Loading {
    private var state: State
    private(set) var loadErrorMessage: String?

    private let lock = NSLock()
    private var loadingTask: Task<Void, Error>?

    init() {
        state = State()
    }

    func updatedState() async throws -> State {
        try await currentLoadingTask().value
        return state
    }

    // updateStatus() is called concurrently across a provider's services that share one store (e.g.
    // a category row and its subservices), so checking-then-creating the task needs to be one atomic
    // operation, not two separate locked accesses — otherwise multiple callers can all see a nil
    // task and each start their own redundant fetch. The lock must not span the await in
    // updatedState(), so this stays synchronous.
    private func currentLoadingTask() -> Task<Void, Error> {
        lock.lock()
        defer { lock.unlock() }

        if let loadingTask {
            return loadingTask
        }

        loadErrorMessage = nil
        let task = createLoadingTask()
        loadingTask = task
        return task
    }

    func retrieveUpdatedState() async throws -> State {
        fatalError("retrieveUpdatedState is not implemented")
    }

    private func createLoadingTask() -> Task<Void, Error> {
        Task { [weak self] in
            guard let self else { return }

            do {
                state = try await retrieveUpdatedState()
            } catch {
                loadErrorMessage = ServiceStatusMessage.from(error)
                throw error
            }

            // Set the task to nil after 5 seconds; This makes it so that calling updatedState() triggers the fetching
            // of new data. (This throttling is to prevent calls to multiple services' updateStatus() from fetching
            // new data again if the network call is too fast)
            _ = Task { [weak self] in
                try await Task.sleep(seconds: 5)
                self?.resetTask()
            }
        }
    }

    private func resetTask() {
        lock.lock()
        defer { lock.unlock() }

        loadingTask = nil
    }
}
