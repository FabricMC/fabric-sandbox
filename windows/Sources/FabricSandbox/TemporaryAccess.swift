import WindowsUtils

class TemporaryAccess {
    private var accessEntries: [AccessEntry] = []

    deinit {
        for entry in accessEntries {
            do {
                try clearAccess(entry.object, trustee: entry.trustee)
            } catch {
                logger.error("Failed to reset access for \(entry.object) for \(entry.trustee): \(error)")
            }
        }
    }

    public func grant(_ object: SecurityObject, trustee: Trustee, accessPermissions: [AccessPermissions]) throws {
        accessEntries.append(AccessEntry(object: object, trustee: trustee))
        try grantAccess(object, trustee: trustee, accessPermissions: accessPermissions)
    }

    public func deny(_ object: SecurityObject, trustee: Trustee, accessPermissions: [AccessPermissions]) throws {
        accessEntries.append(AccessEntry(object: object, trustee: trustee))
        try denyAccess(object, trustee: trustee, accessPermissions: accessPermissions)
    }
}

fileprivate struct AccessEntry {
    let object: SecurityObject
    let trustee: Trustee
}