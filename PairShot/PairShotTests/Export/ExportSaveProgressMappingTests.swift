@testable import PairShot
import Testing

struct ExportSaveProgressMappingTests {
    @Test
    func `ticksTotal 은 jobs × 2 (render + save 양 phase 합)`() {
        #expect(ExportSaveProgressMapping.ticksTotal(jobs: 1) == 2)
        #expect(ExportSaveProgressMapping.ticksTotal(jobs: 5) == 10)
        #expect(ExportSaveProgressMapping.ticksTotal(jobs: 100) == 200)
    }

    @Test
    func `ticksTotal 은 jobs=0 일 때 1 로 clamp — divide-by-zero 방지`() {
        #expect(ExportSaveProgressMapping.ticksTotal(jobs: 0) == 1)
    }

    @Test
    func `processed = done / 2 (integer division) 매끄러운 단조 증가`() {
        let total = 5
        #expect(ExportSaveProgressMapping.processed(done: 0, jobsTotal: total) == 0)
        #expect(ExportSaveProgressMapping.processed(done: 1, jobsTotal: total) == 0)
        #expect(ExportSaveProgressMapping.processed(done: 2, jobsTotal: total) == 1)
        #expect(ExportSaveProgressMapping.processed(done: 3, jobsTotal: total) == 1)
        #expect(ExportSaveProgressMapping.processed(done: 4, jobsTotal: total) == 2)
        #expect(ExportSaveProgressMapping.processed(done: 10, jobsTotal: total) == 5)
    }

    @Test
    func `processed 는 jobsTotal 을 절대 넘지 않음 — over-tick 안전`() {
        #expect(ExportSaveProgressMapping.processed(done: 12, jobsTotal: 5) == 5)
        #expect(ExportSaveProgressMapping.processed(done: 100, jobsTotal: 3) == 3)
        #expect(ExportSaveProgressMapping.processed(done: 1000, jobsTotal: 10) == 10)
    }

    @Test
    func `합성 phase — done 0…N 진행 시 processed 0…N_div_2`() {
        let total = 10
        for done in 0 ... total {
            let processed = ExportSaveProgressMapping.processed(done: done, jobsTotal: total)
            #expect(processed == done / 2)
            #expect(processed <= total / 2)
        }
    }

    @Test
    func `저장 phase — done N+1…2N 진행 시 processed N_div_2…N`() {
        let total = 10
        for done in (total + 1) ... (total * 2) {
            let processed = ExportSaveProgressMapping.processed(done: done, jobsTotal: total)
            #expect(processed == done / 2)
            #expect(processed >= total / 2)
            #expect(processed <= total)
        }
    }

    @Test
    func `합성 phase 끝 시점 (done=N) — progress fraction 50%, processed N_div_2`() {
        let total = 10
        let ticksTotal = ExportSaveProgressMapping.ticksTotal(jobs: total)
        let processed = ExportSaveProgressMapping.processed(done: total, jobsTotal: total)
        let fraction = Double(total) / Double(ticksTotal)

        #expect(fraction == 0.5)
        #expect(processed == 5)
    }

    @Test
    func `전체 파이프라인 완료 시점 (done=2N) — progress 100%, processed N`() {
        let total = 10
        let ticksTotal = ExportSaveProgressMapping.ticksTotal(jobs: total)
        let processed = ExportSaveProgressMapping.processed(done: ticksTotal, jobsTotal: total)
        let fraction = Double(ticksTotal) / Double(ticksTotal)

        #expect(fraction == 1.0)
        #expect(processed == total)
    }

    @Test
    func `partial save failure 시 — done=N+K 에서 정지하면 progress 가 0_5 + K_div_2N 위치`() {
        let total = 10
        let partialSaved = 3
        let doneAtFailure = total + partialSaved
        let ticksTotal = ExportSaveProgressMapping.ticksTotal(jobs: total)
        let processed = ExportSaveProgressMapping.processed(done: doneAtFailure, jobsTotal: total)
        let fraction = Double(doneAtFailure) / Double(ticksTotal)

        #expect(processed == 6)
        #expect(fraction > 0.5)
        #expect(fraction < 1.0)
        #expect(fraction == 0.65)
    }

    @Test
    func `jobs=1 단일 케이스 — done=2 시점에 fraction 1_0, processed 1`() {
        let ticksTotal = ExportSaveProgressMapping.ticksTotal(jobs: 1)
        let processed = ExportSaveProgressMapping.processed(done: 2, jobsTotal: 1)

        #expect(ticksTotal == 2)
        #expect(processed == 1)
    }

    @Test
    func `processed 매핑은 매 2 ticks 마다 1 씩 증가 — UI K_div_N 카운터 매끄러움`() {
        let total = 4
        var lastProcessed = 0
        var jumps = 0
        for done in 1 ... (total * 2) {
            let processed = ExportSaveProgressMapping.processed(done: done, jobsTotal: total)
            if processed > lastProcessed {
                let delta = processed - lastProcessed
                #expect(delta == 1)
                jumps += 1
                lastProcessed = processed
            }
        }
        #expect(jumps == total)
    }
}
