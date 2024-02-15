//
//  File.swift
//  
//
//  Created by Mac on 26/2/2022.
//

import Foundation

public enum FlowConfigure {
    
    case `default`
    case set(timeout: Double = 0, retry: UInt = 0, backoffTime: UInt = 0)
    
    var timeout: Double {
        switch self {
        case .default:
            return 0
        case .set(let timeout, _, _):
            return timeout
        }
    }
    
    var retry: UInt {
        switch self {
        case .default:
            return 0
        case .set(_, let retry, _):
            return retry
        }
    }
    
    var backOffTime: UInt {
        switch self {
        case .default:
            return 0
        case .set(_, _, let backOffTime):
            return backOffTime
        }
    }
}

public protocol FlowCancellable {
    func cancel()
}

public class Flow<SharedParams>: FlowCancellable {
    
    public var params: SharedParams
    
    public class FlowState {
        public var runId: String?
        public var result: Bool?
        public var retryCount = 0
        public var shouldRetry = false
        public var isTimeout = false
        public var error: Error?
    }
    
    private(set) var currentFlowState: FlowState?
    private(set) var currentFlowConfigure: FlowConfigure?
    private(set) var currentTask: Task<Void, Error>?
    
    private(set) var isCancel: Bool = false
    
    public init(_ params: SharedParams) {
        self.params = params
    }
    
    public func cancel() {
        if isCancel {
            return
        }
        isCancel = true
        currentTask?.cancel()
    }
    
    public func result() -> Result<SharedParams, Error> {
        if let error = currentFlowState?.error {
            return .failure(error)
        }
        return .success(self.params)
    }
    
//    public var semaphore = DispatchSemaphore(value: 1)
    public func asyncFlow(with configure: FlowConfigure = .default, execute: @escaping (SharedParams, FlowCancellable) async throws -> Void) async -> Flow {
        await _async(with: configure) { [self] in
            try await execute(params, self)
        }
    }
    
    public func asyncCompletionHandler(with configure: FlowConfigure = .default, executeWithCheckedContinuation: @escaping (SharedParams, CheckedContinuation<Void, Error>, FlowCancellable) -> Void) async -> Flow {
        await _async(with: configure) { [self] in
            try await withCheckedThrowingContinuation { continuation in
                executeWithCheckedContinuation(params, continuation, self)
            }
        }
    }
       
    
    private func _async(with configure: FlowConfigure = .default, execute: @escaping () async throws -> Void) async -> Flow {
        if currentFlowState?.error != nil {
            return self
        }

        currentFlowConfigure = configure
        currentFlowState = FlowState()

        guard let _curFlowState = currentFlowState,
                let _curConfigure = currentFlowConfigure else {
            return self
        }

        var result: Bool?

        repeat {

            let runId = UUID().uuidString
            _curFlowState.runId = runId

            do {
                result = nil

                if isCancel {
                    throw NSError(domain: "Canceled", code: -999, userInfo: [:])
                }
                
                /*
                 wait a little bit time while isRetry flow and back off time has set, greater than 0
                 */
                if _curFlowState.retryCount > 0 && _curConfigure.backOffTime > 0 {
                    try await Task.sleep(nanoseconds: UInt64(_curConfigure.backOffTime) * 1_000_000_000)
                }
                
                /*
                 set timeout for the flow if timeout has set, greater than 0.0
                 */
                
                if _curConfigure.timeout > 0.0 {
                    /*
                     using GCD approach instead of  using Timer due to the reason which has a significant energy cost to using timers
                     https://www.hackingwithswift.com/articles/117/the-ultimate-guide-to-timer
                     */
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + configure.timeout) {
                        if _curFlowState.result == nil && _curFlowState.runId == runId {
                            _curFlowState.isTimeout = true
                            self.currentTask?.cancel()
                        }
                    }
                }
                
                let task = Task {
//                    semaphore.wait()
                    try await execute()
                }
                currentTask = task
//                semaphore.signal()
                switch await task.result {
                case .success():
                    break
                case .failure(let error):
                    throw error
                }

                if _curFlowState.isTimeout {
                    throw NSError(domain: "timeout", code: -999, userInfo: [:])
                }
                result = true
            } catch {
                _curFlowState.error = error
                result = false
            }

            if result == true
                || isCancel == true
                || _curConfigure.retry == 0
                || _curFlowState.retryCount == _curConfigure.retry  {
                _curFlowState.shouldRetry = false
            } else {
                _curFlowState.retryCount += 1
                _curFlowState.error = nil
                _curFlowState.isTimeout = false
                _curFlowState.shouldRetry = true
            }

        } while _curFlowState.shouldRetry

        return self
    }
    
}
