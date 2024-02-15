import XCTest
import AsyncFlow

final class AsyncFlowTests: XCTestCase {
    
    public struct IPAddress: Codable {
        var ip: String?
    }

    public class BL_GetIPs_Parameters {
        var req1Params = [String: Any]()
        var expected1Params = [String: Any]()
        var req2Params = [String: Any]()
        var expected2Params = [String: Any]()
        var req3Params = [String: Any]()
        var expected3Params = [String: Any]()
        var results: Result<Any?, Error>?
    }
    
    func testSimpleUsage() throws {
        let timeout = 10.0
        let expectation = expectation(description: "testSimpleUsage")
        
        class Business_Logic_Parameters {
            var req1Params = [String: Any]()
            var expected1Params = [String: Any]()
            var req2Params = [String: Any]()
            var expected2Params = [String: Any]()
            var req3Params = [String: Any]()
            var expected3Params = [String: Any]()
        }
        
        Task {
            let result = await Flow(Business_Logic_Parameters()).asyncFlow { params, cancellation in
                // fake work task with async/await function
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                params.expected1Params["api_request1"] = "success"
            }.asyncFlow(with: .set(timeout: 10, retry: 1, backoffTime: 2)) { params, cancellation in
                // fake work task with async/await function
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                params.expected2Params["api_request2"] = "success"
            }.asyncCompletionHandler { params, continuation, cancellation in
                // fake work task with completion handler
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    params.expected3Params["api_request3"] = "success"
                    continuation.resume(returning: ())
                }
            }
            XCTAssertEqual(result.params.expected1Params["api_request1"] as! String, "success")
            XCTAssertEqual(result.params.expected2Params["api_request2"] as! String, "success")
            XCTAssertEqual(result.params.expected3Params["api_request3"] as! String, "success")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }
    
    func testSuccessfulCase() throws {
        let timeout = 10.0
        let expectation = expectation(description: "testSuccessfulCase")
        let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        Task {
            let result = await Flow(BL_GetIPs_Parameters()).asyncFlow { params, _ in
                
                try await withCheckedThrowingContinuation { continuation in
                    // then, we call the original fetchData
                    guard let url = URL(string: "https://api.ipify.org?format=json") else {
                        continuation.resume(with: .failure(NSError()))
                        return
                    }
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                        params.expected1Params["ipAddress"] = ipAddress.ip
                        continuation.resume(returning: ())
                    }.resume()
                }
            }.asyncFlow { params, _ in
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    throw NSError()
                }
                var result: (Data, URLResponse)?
                if #available(iOS 15.0, *) {
                    result = try await URLSession.shared.data(from: url)
                } else {
                    result = try await withCheckedThrowingContinuation { continuation in
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            continuation.resume(returning: (data!, response!))
                        }.resume()
                    }
                }
                let ipAddress = try JSONDecoder().decode(IPAddress.self, from: result!.0)
                params.expected2Params["ipAddress"] = ipAddress.ip
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as! String), ipAddress)
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as! String), ipAddress)
            expectation.fulfill()
        }
        
        
        wait(for: [expectation], timeout: timeout)
    }
    
    func testTimeoutAndRetryWithFailResult() {
        
        let timeout = 10.0
        let expectation = expectation(description: "testTimeoutAndRetryWithFailResult")
        _ = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        Task {
            let result = await Flow(BL_GetIPs_Parameters()).asyncFlow(with: .set(timeout: 1, retry: 1)) { params, _ in
                print("1111")
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
//                try! await Task.sleep(nanoseconds: 2 * 1_000_000_000)
//                try await withCheckedThrowingContinuation { continuation in
//                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
//                        continuation.resume(returning: ())
//                    }
//                }
            }.asyncFlow { params, _ in
                try await withCheckedThrowingContinuation { continuation in
                    print("2222")
                    guard let url = URL(string: "https://api.ipify.org?format=json") else {
                        continuation.resume(with: .failure(NSError()))
                        return
                    }
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                        params.expected1Params["ipAddress"] = ipAddress.ip
                        continuation.resume(returning: ())
                    }.resume()
                }
            }.asyncFlow { params, _ in
                print("3333")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    throw NSError()
                }
                var result: (Data, URLResponse)?
                if #available(iOS 15.0, *) {
                    result = try await URLSession.shared.data(from: url)
                } else {
                    result = try await withCheckedThrowingContinuation { continuation in
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            continuation.resume(returning: (data!, response!))
                        }.resume()
                    }
                }
                let ipAddress = try JSONDecoder().decode(IPAddress.self, from: result!.0)
                params.expected2Params["ipAddress"] = ipAddress.ip
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as? String) ?? "", "")
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as? String) ?? "", "")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    func testCancel() throws {
        let timeout = 10.0
        let expectation = expectation(description: "testCancel")
        _ = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        
        Task {
            let flow = Flow(BL_GetIPs_Parameters())
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1) {
                flow.cancel()
            }
            
            let result = await flow.asyncFlow { params, _ in
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
                        continuation.resume(returning: ())
                    }
                }
            }.asyncFlow { params, _ in
                try await withCheckedThrowingContinuation { continuation in
                    guard let url = URL(string: "https://api.ipify.org?format=json") else {
                        continuation.resume(with: .failure(NSError()))
                        return
                    }
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                        params.expected1Params["ipAddress"] = ipAddress.ip
                        continuation.resume(returning: ())
                    }.resume()
                }
            }.asyncFlow { params, _ in
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    throw NSError()
                }
                var result: (Data, URLResponse)?
                if #available(iOS 15.0, *) {
                    result = try await URLSession.shared.data(from: url)
                } else {
                    result = try await withCheckedThrowingContinuation { continuation in
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            continuation.resume(returning: (data!, response!))
                        }.resume()
                    }
                }
                let ipAddress = try JSONDecoder().decode(IPAddress.self, from: result!.0)
                params.expected2Params["ipAddress"] = ipAddress.ip
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as? String) ?? "", "")
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as? String) ?? "", "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }
    
    func testCompletionTimeoutAndRetryWithFailResult() {
        
        let timeout = 10.0
        let expectation = expectation(description: "testCompletionTimeoutAndRetryWithFailResult")
        _ = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        Task {
            let result = await Flow(BL_GetIPs_Parameters()).asyncCompletionHandler(with: .set(timeout: 1, retry: 1)) { params, continuation, _ in
                print("1111")
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    continuation.resume(returning: ())
                }
            }.asyncCompletionHandler { params, continuation, _ in
                print("2222")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    continuation.resume(with: .failure(NSError()))
                    return
                }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                    params.expected1Params["ipAddress"] = ipAddress.ip
                    continuation.resume(returning: ())
                }.resume()
            }.asyncCompletionHandler { params, continuation, _ in
                print("3333")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    continuation.resume(with: .failure(NSError()))
                    return
                }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                    params.expected2Params["ipAddress"] = ipAddress.ip
                    continuation.resume(returning: ())
                }.resume()
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as? String) ?? "", "")
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as? String) ?? "", "")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    func testAsyncAndCompletionTimeoutAndRetryWithFailResult() {
        
        let timeout = 10.0
        let expectation = expectation(description: "testAsyncAndCompletionTimeoutAndRetryWithFailResult")
        _ = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        Task {
            let result = await Flow(BL_GetIPs_Parameters()).asyncCompletionHandler(with: .set(timeout: 1, retry: 1)) { params, continuation, _ in
                print("1111")
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    continuation.resume(returning: ())
                }
            }.asyncCompletionHandler { params, continuation, _ in
                print("2222")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    continuation.resume(with: .failure(NSError()))
                    return
                }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                    params.expected1Params["ipAddress"] = ipAddress.ip
                    continuation.resume(returning: ())
                }.resume()
            }.asyncFlow { params, _ in
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    throw NSError()
                }
                var result: (Data, URLResponse)?
                if #available(iOS 15.0, *) {
                    result = try await URLSession.shared.data(from: url)
                } else {
                    result = try await withCheckedThrowingContinuation { continuation in
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            continuation.resume(returning: (data!, response!))
                        }.resume()
                    }
                }
                let ipAddress = try JSONDecoder().decode(IPAddress.self, from: result!.0)
                params.expected2Params["ipAddress"] = ipAddress.ip
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as? String) ?? "", "")
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as? String) ?? "", "")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    func testAsyncAndCompletionTimeoutAndRetryWithSuccessResult() {
        let timeout = 10.0
        let expectation = expectation(description: "testAsyncAndCompletionTimeoutAndRetryWithSuccessResult")
        let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        Task {
            let result = await Flow(BL_GetIPs_Parameters()).asyncCompletionHandler(with: .set(timeout: 1, retry: 1)) { params, continuation, _ in
                print("1111")
                continuation.resume(returning: ())
            }.asyncCompletionHandler { params, continuation, _ in
                print("2222")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    continuation.resume(with: .failure(NSError()))
                    return
                }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                    params.expected1Params["ipAddress"] = ipAddress.ip
                    continuation.resume(returning: ())
                }.resume()
            }.asyncFlow { params, _ in
                print("3333")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    throw NSError()
                }
                var result: (Data, URLResponse)?
                if #available(iOS 15.0, *) {
                    result = try await URLSession.shared.data(from: url)
                } else {
                    result = try await withCheckedThrowingContinuation { continuation in
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            continuation.resume(returning: (data!, response!))
                        }.resume()
                    }
                }
                let ipAddress = try JSONDecoder().decode(IPAddress.self, from: result!.0)
                params.expected2Params["ipAddress"] = ipAddress.ip
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as? String) ?? "", ipAddress)
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as? String) ?? "", ipAddress)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    func testCancelInAsyncCompletion() {
        let timeout = 10.0
        let expectation = expectation(description: "testCancelInAsyncCompletion")
        let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: try! String(contentsOf: URL(string: "https://api.ipify.org?format=json")!).data(using: .utf8)!).ip
        Task {
            let result = await Flow(BL_GetIPs_Parameters()).asyncCompletionHandler(with: .set(timeout: 1, retry: 1)) { params, continuation, cancellation in
                print("1111")
                cancellation.cancel()
                continuation.resume(returning: ())
            }.asyncCompletionHandler { params, continuation, _ in
                print("2222")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    continuation.resume(with: .failure(NSError()))
                    return
                }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                    params.expected1Params["ipAddress"] = ipAddress.ip
                    continuation.resume(returning: ())
                }.resume()
            }.asyncCompletionHandler { params, continuation, _ in
                print("2222")
                guard let url = URL(string: "https://api.ipify.org?format=json") else {
                    continuation.resume(with: .failure(NSError()))
                    return
                }
                URLSession.shared.dataTask(with: url) { data, response, error in
                    let ipAddress = try! JSONDecoder().decode(IPAddress.self, from: data!)
                    params.expected2Params["ipAddress"] = ipAddress.ip
                    continuation.resume(returning: ())
                }.resume()
            }
            
            XCTAssertEqual((result.params.expected1Params["ipAddress"] as? String) ?? "", "")
            XCTAssertEqual((result.params.expected2Params["ipAddress"] as? String) ?? "", "")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }
    
    func testRetryWithBackOffTime() {
        let timeout = 20.0
        let expectation = expectation(description: "testCancelInAsyncCompletion")
        let runStep = [String]()
        Task {
            var start = Date()
            let result = await Flow(BL_GetIPs_Parameters()).asyncCompletionHandler(with: .set(timeout: 5, retry: 1, backoffTime: 2)) { params, continuation, cancellation in
                print("1111")
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    continuation.resume(returning: ())
                }
            }.asyncCompletionHandler { params, continuation, _ in
                print("2222")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    continuation.resume(returning: ())
                }
            }.asyncCompletionHandler { params, continuation, _ in
                print("3333")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    continuation.resume(returning: ())
                }
            }
            
            var end = Date()
            
            var diff = end.timeIntervalSince1970 - start.timeIntervalSince1970
            print(diff)
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 19) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }
    
    func testAsyncFlowRetryWithBackOffTime() {
        let timeout = 20.0
        let expectation = expectation(description: "testCancelInAsyncCompletion")
        
        Task {
            var runStep = [String]()
            let start = Date()
            let result = await Flow(BL_GetIPs_Parameters()).asyncFlow(with: .set(timeout: 5, retry: 1, backoffTime: 2)) { params, cancellation in
                if runStep.count == 0 {
                    runStep.append("1111")
                    try await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                } else {
                    runStep.append("1111")
                    try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                }
            }.asyncFlow { params, _ in
                runStep.append("2222")
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            }.asyncFlow { params, _ in
                runStep.append("3333")
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            }
            
            let end = Date()
            let diff = end.timeIntervalSince1970 - start.timeIntervalSince1970
            print(diff)
            
            XCTAssertEqual(runStep[1], "1111")
            XCTAssertEqual(runStep[2], "2222")
            XCTAssertEqual(runStep[3], "3333")
            XCTAssertLessThan(diff, 18.0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }
    
}
