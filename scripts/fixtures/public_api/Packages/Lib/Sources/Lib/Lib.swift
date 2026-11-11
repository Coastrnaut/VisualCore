// Fixture for check_public_api.py tests.
/// A documented type.
public struct Documented {
    /// Documented property.
    public var value: Int
    public func undocumentedMethod() {}
    /// Documented initializer.
    @inlinable
    public init(value: Int) { self.value = value }
}

/** Block-documented function. */
public func blockDocumented() {}

internal struct NotPublic {}
