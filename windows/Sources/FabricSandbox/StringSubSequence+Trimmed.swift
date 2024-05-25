public extension String.SubSequence {
    func trimmed() -> String {
        return String(self).trimmed()
    }
}

public extension String {
    func trimmed() -> String {
        return String(
            self.drop(while: { $0.isWhitespace })
                .reversed()
                .drop(while: { $0.isWhitespace })
                .reversed()
        )
    }
}