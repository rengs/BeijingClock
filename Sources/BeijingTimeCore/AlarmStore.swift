import Foundation

public enum AlarmBookError: Error, Equatable {
    case tooMany
    case duplicateID
    case missing
}

public enum AlarmBook {
    public static let maximumCount = 100

    public static func adding(_ alarm: Alarm, to state: PersistedState) -> Result<PersistedState, AlarmBookError> {
        guard state.alarms.count < maximumCount else { return .failure(.tooMany) }
        guard !state.alarms.contains(where: { $0.id == alarm.id }) else { return .failure(.duplicateID) }
        var copy = state
        copy.alarms.append(alarm)
        return .success(copy)
    }

    public static func updating(_ alarm: Alarm, in state: PersistedState) -> Result<PersistedState, AlarmBookError> {
        guard let index = state.alarms.firstIndex(where: { $0.id == alarm.id }) else {
            return .failure(.missing)
        }
        var copy = state
        copy.alarms[index] = alarm
        return .success(copy)
    }

    public static func deleting(id: UUID, from state: PersistedState) -> PersistedState {
        var copy = state
        copy.alarms.removeAll { $0.id == id }
        copy.handled.removeAll { $0.alarmID == id }
        return copy
    }

    public static func toggling(id: UUID, in state: PersistedState) -> Result<PersistedState, AlarmBookError> {
        guard let index = state.alarms.firstIndex(where: { $0.id == id }) else {
            return .failure(.missing)
        }
        var copy = state
        copy.alarms[index].enabled.toggle()
        return .success(copy)
    }
}

public struct LoadResult: Equatable {
    public var state: PersistedState
    public var backupURL: URL?

    public init(state: PersistedState, backupURL: URL?) {
        self.state = state
        self.backupURL = backupURL
    }
}

public enum StoreError: Error, Equatable {
    case unsupportedSchema
}

public final class AlarmStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupportFileURL() -> URL {
        let roots = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let root = roots.first ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return root
            .appendingPathComponent("BeijingClock", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    public func load() throws -> LoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadResult(state: .empty, backupURL: nil)
        }
        let data = try Data(contentsOf: fileURL)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            guard state.schemaVersion == PersistedState.schema else {
                throw StoreError.unsupportedSchema
            }
            return LoadResult(state: state, backupURL: nil)
        } catch {
            let backup = fileURL
                .deletingLastPathComponent()
                .appendingPathComponent("state.bad-\(UUID().uuidString).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return LoadResult(state: .empty, backupURL: backup)
        }
    }

    public func save(_ state: PersistedState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
