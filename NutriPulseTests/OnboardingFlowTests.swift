import XCTest
@testable import Footing

@MainActor
final class OnboardingFlowTests: XCTestCase {
    func testFocusRequiresBothExplicitApprovalAndPermission() {
        let vm = OnboardingViewModel(), owner = UUID()
        vm.focusDraft = "Help me keep meals simple."
        XCTAssertNil(vm.focusMemory(userId: owner, requested: false, allowed: true))
        XCTAssertNil(vm.focusMemory(userId: owner, requested: true, allowed: false))
        XCTAssertNotNil(vm.focusMemory(userId: owner, requested: true, allowed: true))
    }
    func testApprovedFocusPreservesWordsAndStableRetryIdentity() throws {
        let vm = OnboardingViewModel(), owner = UUID()
        vm.focusDraft = "Keep meals simple and protect my muscle, especially when I’m busy."
        let first = try XCTUnwrap(vm.focusMemory(userId: owner, requested: true, allowed: true))
        let retry = try XCTUnwrap(vm.focusMemory(userId: owner, requested: true, allowed: true))
        XCTAssertEqual(first.id, retry.id)
        XCTAssertEqual(first.userId, owner)
        XCTAssertEqual(first.content, vm.focusDraft)
        vm.focusDraft = "My revised focus"
        let edited = try XCTUnwrap(vm.focusMemory(userId: owner, requested: true, allowed: true))
        XCTAssertEqual(first.id, edited.id)
        XCTAssertEqual(edited.content, "My revised focus")
    }
    func testSkippedEmptyAndOversizedFocusCannotCreateMemory() {
        let vm = OnboardingViewModel(), owner = UUID()
        vm.focusDraft = " \n "
        XCTAssertNil(vm.focusMemory(userId: owner, requested: true, allowed: true))
        vm.focusDraft = String(repeating: "a", count: 301)
        XCTAssertNil(vm.focusMemory(userId: owner, requested: true, allowed: true))
    }
    func testBasicsRequireAdultConfirmationAndRejectInvalidMeasurements() {
        let vm = OnboardingViewModel()
        vm.fullName = "Alex"
        XCTAssertFalse(vm.canContinueBasics)
        vm.adultConfirmed = true
        XCTAssertTrue(vm.canContinueBasics)
        vm.dob = Calendar.current.date(byAdding: .year, value: -17, to: .now)!
        XCTAssertFalse(vm.canContinueBasics)
        vm.dob = Calendar.current.date(byAdding: .year, value: -30, to: .now)!
        vm.heightCm = .nan
        XCTAssertFalse(vm.canContinueBasics)
        vm.heightCm = 170; vm.weightKg = 0
        XCTAssertFalse(vm.canContinueBasics)
    }
    func testCustomTargetsSurviveReviewAndResetUsesLatestProfile() {
        let vm = OnboardingViewModel()
        var goals = vm.calculatedGoals
        goals.proteinG = 130; goals.calories = 2000
        vm.customGoals = goals
        vm.weightKg = 100
        XCTAssertEqual(vm.selectedGoals.calories, 2000)
        XCTAssertEqual(vm.selectedGoals.proteinG, 130)
        XCTAssertTrue(vm.areTargetsValid)
        vm.customGoals = nil
        XCTAssertEqual(vm.selectedGoals.calories, vm.calculatedGoals.calories)
    }
    func testInvalidTargetsCannotFinish() {
        let vm = OnboardingViewModel()
        var goals = vm.calculatedGoals
        goals.calories = .infinity
        vm.customGoals = goals
        XCTAssertFalse(vm.areTargetsValid)
        goals.calories = 2000; goals.waterMlTarget = -1; vm.customGoals = goals
        XCTAssertFalse(vm.areTargetsValid)
    }
    func testNewFlowDoesNotReuseAnotherDraft() {
        let first = OnboardingViewModel()
        first.focusDraft = "Private focus"; first.adultConfirmed = true; first.previewPulseAllowed = true
        let next = OnboardingViewModel()
        XCTAssertTrue(next.focusDraft.isEmpty)
        XCTAssertFalse(next.adultConfirmed)
        XCTAssertFalse(next.canSaveFocus(preview: true))
    }
}

@MainActor
private final class OnboardingMemoryRepository: PulseMemoryRepositoryProtocol {
    var rows: [PulseMemory] = []
    var failSave = false
    var fetchedOwners: [UUID] = []
    func fetch(userId: UUID) async throws -> [PulseMemory] { fetchedOwners.append(userId); return rows }
    func save(_ memory: PulseMemory) async throws {
        if failSave { throw URLError(.notConnectedToInternet) }
        rows.removeAll { $0.id == memory.id }; rows.append(memory)
    }
    func delete(_ memory: PulseMemory) async throws { rows.removeAll { $0.id == memory.id && $0.userId == memory.userId } }
}

extension OnboardingFlowTests {
    func testInterruptedFocusSaveRetriesAndSkipRemovesOnlyThisAttemptsMemory() async throws {
        let repo = OnboardingMemoryRepository(), owner = UUID()
        let vm = OnboardingViewModel(focusRepository: repo)
        vm.focusDraft = "Make mornings easier."
        repo.failSave = true
        do { try await vm.persistFocus(userId: owner, requested: true, allowed: true); XCTFail("Expected offline failure") }
        catch { XCTAssertTrue(repo.rows.isEmpty) }
        repo.failSave = false
        try await vm.persistFocus(userId: owner, requested: true, allowed: true)
        try await vm.persistFocus(userId: owner, requested: true, allowed: true)
        XCTAssertEqual(repo.rows.count, 1)
        try await vm.persistFocus(userId: owner, requested: false, allowed: true)
        XCTAssertTrue(repo.rows.isEmpty)
    }
    func testRestartDeduplicatesApprovedContentWithoutDeletingExistingMemoryOnSkip() async throws {
        let repo = OnboardingMemoryRepository(), owner = UUID()
        let original = PulseMemory(userId: owner, content: "Keep meals simple.")
        repo.rows = [original, PulseMemory(userId: UUID(), content: "Other user private focus")]
        let vm = OnboardingViewModel(focusRepository: repo)
        vm.focusDraft = "keep meals simple."
        try await vm.persistFocus(userId: owner, requested: true, allowed: true)
        XCTAssertEqual(repo.rows.count, 2)
        try await vm.persistFocus(userId: owner, requested: false, allowed: true)
        XCTAssertTrue(repo.rows.contains(original))
        XCTAssertEqual(repo.fetchedOwners, [owner])
    }
    func testDeclinedPermissionDoesNotReadOrWriteMemories() async throws {
        let repo = OnboardingMemoryRepository(), owner = UUID()
        let vm = OnboardingViewModel(focusRepository: repo); vm.focusDraft = "My focus"
        try await vm.persistFocus(userId: owner, requested: true, allowed: false)
        XCTAssertTrue(repo.fetchedOwners.isEmpty); XCTAssertTrue(repo.rows.isEmpty)
    }
}
