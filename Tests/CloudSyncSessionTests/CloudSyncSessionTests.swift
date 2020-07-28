import Combine
import XCTest
@testable import CloudSyncSession

class MockModifyRecordsOperation: ModifyOperation {
    var records = [CKRecord]()

    required init() {}
}

class SuccessfulMockOperationHandler: OperationHandler {
    func handle(modifyOperation: ModifyOperation, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) {
            completion(.success(modifyOperation.records))
        }
    }
}

class FailingMockOperationHandler: OperationHandler {
    func handle(modifyOperation: ModifyOperation, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) {
            completion(.failure(CKError(.notAuthenticated)))
        }
    }
}

private var testIdentifier = "8B14FD76-EA56-49B0-A184-6C01828BA20A"

private var testRecord = CKRecord(
    recordType: "Test",
    recordID: CKRecord.ID(recordName: testIdentifier)
)

final class CloudSyncSessionTests: XCTestCase {
    func testUnhaltsAfterAccountAvailable() {
        let mockOperationHandler = SuccessfulMockOperationHandler()
        let session = CloudSyncSession<MockModifyRecordsOperation>(
            operationHandler: mockOperationHandler
        )

        session.dispatch(event: .accountStatusChanged(.available))

        XCTAssertEqual(session.state.isHalted, false)
    }

    func testModifySuccess() {
        let expectation = self.expectation(description: "work")

        let mockOperationHandler = SuccessfulMockOperationHandler()
        let initialState = SyncState<MockModifyRecordsOperation>(isHalted: false)
        let session = CloudSyncSession<MockModifyRecordsOperation>(
            initialState: initialState,
            operationHandler: mockOperationHandler
        )

        session.onRecordsModified = { records in
            XCTAssertEqual(records.count, 1)
            XCTAssertNil(session.state.currentWork)

            expectation.fulfill()
        }

        session.dispatch(event: .modify([testRecord]))

        wait(for: [expectation], timeout: 1)
    }

    func testModifyFailure() {
        var tasks = Set<AnyCancellable>()
        let expectation = self.expectation(description: "work")

        let mockOperationHandler = FailingMockOperationHandler()
        let initialState = SyncState<MockModifyRecordsOperation>(isHalted: false)
        let session = CloudSyncSession<MockModifyRecordsOperation>(
            initialState: initialState,
            operationHandler: mockOperationHandler
        )

        session.onRecordsModified = { records in
            XCTFail()
        }

        session.$state
            .sink { newState in
                if newState.isHalted {
                    expectation.fulfill()
                }
            }
            .store(in: &tasks)

        session.dispatch(event: .modify([testRecord]))

        wait(for: [expectation], timeout: 1)
    }

    func testHaltedIgnoresModifyEvents() {
        let expectation = self.expectation(description: "work")
        expectation.isInverted = true

        let mockOperationHandler = SuccessfulMockOperationHandler()
        let initialState = SyncState<MockModifyRecordsOperation>(isHalted: true)
        let session = CloudSyncSession<MockModifyRecordsOperation>(
            initialState: initialState,
            operationHandler: mockOperationHandler
        )

        session.onRecordsModified = { records in
            expectation.fulfill()
        }

        session.dispatch(event: .modify([testRecord]))

        wait(for: [expectation], timeout: 1)
    }
}