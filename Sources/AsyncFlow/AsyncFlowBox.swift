//
//  File.swift
//  
//
//  Created by Mac on 16/3/2022.
//

import Foundation

public class AsyncFlowBox<T> {
    public var value: T?
    
    public init(_ value: T?) {
        self.value = value
    }
}
