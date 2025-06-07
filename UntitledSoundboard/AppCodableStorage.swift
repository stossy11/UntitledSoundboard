//
//  AppCodableStorage.swift
//  BadSoundboard™
//
//  Created by Stossy11 on 24/05/2025.
//


import SwiftUI

@propertyWrapper
struct AppCodableStorage<Value: Codable & Equatable>: DynamicProperty {
    @State private var stateValue: Value

    private let key: String
    private let defaultValue: Value
    private let storage: UserDefaults

    init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = store

        let initialValue: Value
        if let data = store.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Value.self, from: data) {
            initialValue = decoded
        } else {
            initialValue = defaultValue
        }

        _stateValue = State(initialValue: initialValue)
    }

    var wrappedValue: Value {
        get { stateValue }
        nonmutating set {
            stateValue = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                storage.set(data, forKey: key)
            }
        }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in self.wrappedValue = newValue }
        )
    }
}
