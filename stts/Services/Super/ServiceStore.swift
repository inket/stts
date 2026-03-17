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

    @Atomic private var loadingTask: Task<Void, Error>?

    init() {
        state = State()
    }

    func updatedState() async throws -> State {
        if loadingTask == nil {
            loadErrorMessage = nil
            loadingTask = createLoadingTask()
        }

        try await loadingTask?.value
        return state
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
            Task { [weak self] in
                try await Task.sleep(seconds: 5)
                self?.resetTask()
            }
        }
    }

    private func resetTask() {
        loadingTask = nil
    }
}
