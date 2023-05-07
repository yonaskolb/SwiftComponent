//
//  File.swift
//  
//
//  Created by Yonas Kolb on 14/6/2023.
//

import Foundation

public protocol ComponentEnvironment {

    static var preview: Self { get }
}

public struct EmptyEnvironment: ComponentEnvironment {
    public static var preview: EmptyEnvironment { .init() }
}
