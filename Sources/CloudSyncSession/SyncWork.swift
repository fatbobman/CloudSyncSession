import CloudKit

public enum SyncWork: Equatable {
    public enum Result {
        case modify(ModifyOperation.Response)
        case fetch(FetchOperation.Response)
        case createZone(Bool)
    }

    case modify(ModifyOperation)
    case fetch(FetchOperation)
    case createZone(CreateZoneOperation)

    var retryCount: Int {
        switch self {
        case .modify(let operation):
            return operation.retryCount
        case .fetch(let operation):
            return operation.retryCount
        case .createZone(let operation):
            return operation.retryCount
        }
    }

    var retried: SyncWork {
        switch self {
        case .modify(var operation):
            operation.retryCount += 1

            return .modify(operation)
        case .fetch(var operation):
            operation.retryCount += 1

            return .fetch(operation)
        case .createZone(var operation):
            operation.retryCount += 1

            return .createZone(operation)
        }
    }

    var debugDescription: String {
        switch self {
        case .modify(let operation):
            return "modify with \(operation.records.count) records to save and \(operation.recordIDsToDelete.count) to delete"
        case .fetch:
            return "fetch"
        case .createZone:
            return "create zone"
        }
    }
}

protocol SyncOperation {
    var retryCount: Int { get set }
}

public struct FetchOperation: Equatable {
    public struct Response {
        let changeToken: CKServerChangeToken?
        let changedRecords: [CKRecord]
        let deletedRecordIDs: [CKRecord.ID]
        let hasMore: Bool
    }

    var changeToken: CKServerChangeToken?
    var retryCount: Int = 0

    public init(changeToken: CKServerChangeToken?) {
        self.changeToken = changeToken
    }
}

public struct ModifyOperation: Equatable, SyncOperation {
    public struct Response {
        let savedRecords: [CKRecord]
        let deletedRecordIDs: [CKRecord.ID]
    }

    var records: [CKRecord]
    var recordIDsToDelete: [CKRecord.ID]
    var retryCount: Int = 0

    public init(records: [CKRecord], recordIDsToDelete: [CKRecord.ID]) {
        self.records = records
        self.recordIDsToDelete = recordIDsToDelete
    }

    var split: [ModifyOperation] {
        let firstHalfRecords = Array(records[0 ..< records.count / 2])
        let secondHalfRecords = Array(records[records.count / 2 ..< records.count])

        let firstHalfDeletedRecordIDs = Array(recordIDsToDelete[0 ..< recordIDsToDelete.count / 2])
        let secondHalfDeletedRecordIDs = Array(recordIDsToDelete[recordIDsToDelete.count / 2 ..< recordIDsToDelete.count])

        return [
            ModifyOperation(records: firstHalfRecords, recordIDsToDelete: firstHalfDeletedRecordIDs),
            ModifyOperation(records: secondHalfRecords, recordIDsToDelete: secondHalfDeletedRecordIDs),
        ]
    }
}

public struct CreateZoneOperation: Equatable {
    var zoneIdentifier: CKRecordZone.ID
    var retryCount: Int = 0

    public init(zoneIdentifier: CKRecordZone.ID) {
        self.zoneIdentifier = zoneIdentifier
    }
}
