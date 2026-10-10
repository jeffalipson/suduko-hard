extension Array {
    /// All `k`-element combinations, in lexicographic index order.
    func combinations(of k: Int) -> [[Element]] {
        guard k > 0 else { return [[]] }
        guard count >= k else { return [] }
        var result: [[Element]] = []
        var idx = Array<Int>(0..<k)
        while true {
            result.append(idx.map { self[$0] })
            var i = k - 1
            while i >= 0 && idx[i] == count - k + i { i -= 1 }
            if i < 0 { return result }
            idx[i] += 1
            for j in (i + 1)..<k { idx[j] = idx[j - 1] + 1 }
        }
    }
}
