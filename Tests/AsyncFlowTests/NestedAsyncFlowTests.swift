//
//  NestedAsyncFlowTests.swift
//  
//
//  Created by paco_yeung on 28/4/2022.
//

import XCTest
import AsyncFlow

class NestedAsyncFlowTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let timeout = 10.0
        let expectation = expectation(description: "testSuccessfulCase")
        
        
        Task {
            let result = await Flow(AsyncFlowBox<[String]>([])).asyncFlow(execute: { params, cancellation in
                print("1")
                let nestedResult = await Flow(AsyncFlowBox<[String]>([])).asyncFlow(execute: { nestedParams, nestedCancellation in
                    print("1 nested 1")
                }).asyncFlow(execute: { _, _ in
                    print("1 nested 2")
                }).asyncCompletionHandler(executeWithCheckedContinuation: { nestedParams, nestedContinuation, nestedCancellation in
                    print("1 nested 3")
                    nestedParams.value = ["AA"]
                    DispatchQueue.main.async {
                        nestedContinuation.resume()
                    }
                })
                params.value = nestedResult.params.value
            }).asyncFlow(execute: { params, cancellation in
                print("2")
                let nestedResult = await Flow(AsyncFlowBox<[String]>([])).asyncFlow(execute: { nestedParams, nestedCancellation in
                    print("2 nested 1")
                }).asyncFlow(execute: { _, _ in
                    print("2 nested 2")
                }).asyncCompletionHandler(executeWithCheckedContinuation: { nestedParams, nestedContinuation, nestedCancellation in
                    print("2 nested 3")
                    nestedParams.value = ["AA"]
                    DispatchQueue.main.async {
                        nestedContinuation.resume()
                    }
                })
                params.value = nestedResult.params.value
            })
            XCTAssertEqual(result.params.value![0], "AA")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }

    
    func testNestedCallWithSameSharedParameterReference() throws {
        let timeout = 10.0
        let expectation = expectation(description: "testSuccessfulCase")
        
        
        Task {
            let _param = AsyncFlowBox<[String]>([])
            let result = await Flow(_param).asyncFlow(execute: { params, cancellation in
                print("1")
                let nestedResult = await Flow(_param).asyncFlow(execute: { nestedParams, nestedCancellation in
                    print("1 nested 1")
                }).asyncFlow(execute: { _, _ in
                    print("1 nested 2")
                }).asyncCompletionHandler(executeWithCheckedContinuation: { nestedParams, nestedContinuation, nestedCancellation in
                    print("1 nested 3")
                    nestedParams.value = ["AA"]
                    DispatchQueue.main.async {
                        nestedContinuation.resume()
                    }
                })
//                params.value = nestedResult.params.value
            }).asyncFlow(execute: { params, cancellation in
                print("2")
                let nestedResult = await Flow(_param).asyncFlow(execute: { nestedParams, nestedCancellation in
                    print("2 nested 1")
                }).asyncFlow(execute: { _, _ in
                    print("2 nested 2")
                }).asyncCompletionHandler(executeWithCheckedContinuation: { nestedParams, nestedContinuation, nestedCancellation in
                    print("2 nested 3")
                    nestedParams.value = ["AA"]
                    DispatchQueue.main.async {
                        nestedContinuation.resume()
                    }
                })
//                params.value = nestedResult.params.value
            })
            XCTAssertEqual(result.params.value![0], "AA")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}
