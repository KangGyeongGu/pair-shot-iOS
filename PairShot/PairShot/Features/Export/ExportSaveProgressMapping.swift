nonisolated enum ExportSaveProgressMapping {
    static func ticksTotal(jobs: Int) -> Int {
        max(1, jobs * 2)
    }

    static func processed(done: Int, jobsTotal: Int) -> Int {
        let totalJobs = max(1, jobsTotal)
        return min(done / 2, totalJobs)
    }
}
