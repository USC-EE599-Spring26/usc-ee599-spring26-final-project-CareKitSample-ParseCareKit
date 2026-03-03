//
//  Profile.swift
//  OCKSample
//
//  Created by Corey Baker on 11/25/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import CareKit
import CareKitStore
import CareKitEssentials
import HealthKit
import SwiftUI
import os.log

@MainActor
class ProfileViewModel: ObservableObject {

    // MARK: Public read/write properties

    var firstName = ""
    var lastName = ""
    var birthday = Date()

    var patient: OCKPatient? {
        willSet {
            if let currentFirstName = newValue?.name.givenName {
                firstName = currentFirstName
            }
            if let currentLastName = newValue?.name.familyName {
                lastName = currentLastName
            }
            if let currentBirthday = newValue?.birthday {
                birthday = currentBirthday
            }
        }
    }

    // MARK: Helpers (public)

    func updatePatient(_ patient: OCKAnyPatient) {
        guard let patient = patient as? OCKPatient else {
            return
        }
        self.patient = patient
    }

    // MARK: User intentional behavior

    func saveProfile() async throws {

        guard var patientToUpdate = patient else {
            throw AppError.errorString("The profile is missing the Patient")
        }

        // If there is a currentPatient that was fetched, check to see if any of the fields changed
        var patientHasBeenUpdated = false

        if patient?.name.givenName != firstName {
            patientHasBeenUpdated = true
            patientToUpdate.name.givenName = firstName
        }

        if patient?.name.familyName != lastName {
            patientHasBeenUpdated = true
            patientToUpdate.name.familyName = lastName
        }

        if patient?.birthday != birthday {
            patientHasBeenUpdated = true
            patientToUpdate.birthday = birthday
        }

        if patientHasBeenUpdated {
            if let anyPatient = try await AppDelegateKey.defaultValue?.store.updateAnyPatient(patientToUpdate),
               let updatedPatient = anyPatient as? OCKPatient {
                self.patient = updatedPatient
                Logger.profile.info("Successfully updated patient and synced local state.")
            } else {
                Logger.profile.error("Patient was updated in store but could not be cast to OCKPatient.")
            }
        }
    }
}

enum TaskCardStyle: String, CaseIterable, Identifiable {
    case instructions
    case simple
    case buttonLog
    case checklist
    case featured
    case grid
    case link
    case numericProgress
    case labeledValue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instructions:
            return "Instruction"
        case .simple:
            return "Simple"
        case .buttonLog:
            return "Button"
        case .checklist:
            return "Checklist"
        case .featured:
            return "Featured"
        case .grid:
            return "Grid"
        case .link:
            return "Link"
        case .numericProgress:
            return "Numeric Progress"
        case .labeledValue:
            return "Labeled Value"
        }
    }

    static var creationOptions: [TaskCardStyle] {
        [ .buttonLog, .checklist, .featured, .grid, .instructions, .labeledValue, .link, .numericProgress, .simple ]
    }

    var healthKitCompatibleStyle: TaskCardStyle {
        switch self {
        case .numericProgress, .labeledValue:
            return self
        default:
            return .numericProgress
        }
    }
}

enum ManagedTaskType: Equatable {
    case task
    case healthKitTask
    case unknown

    var displayName: String {
        switch self {
        case .task:
            return "Task"
        case .healthKitTask:
            return "HealthKitTask"
        case .unknown:
            return "Task"
        }
    }
}

@MainActor
final class TaskManagementViewModel: ObservableObject {
    @Published var title = ""
    @Published var instructions = ""
    @Published var assetSymbol = "checkmark.circle"
    @Published var selectedCardStyle: TaskCardStyle = .instructions
    @Published var scheduleTime = Date()
    @Published private(set) var tasks: [ManagedTaskItem] = []
    @Published private(set) var statusMessage = ""
    @Published private(set) var hasError = false
    @Published private(set) var isProcessing = false
    private var taskCache: [String: any OCKAnyTask] = [:]
}

extension TaskManagementViewModel {
    func createCareTask() async {
        guard !isProcessing else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            hasError = true
            statusMessage = "Task title is required."
            return
        }

        guard let store = AppDelegateKey.defaultValue?.store else {
            hasError = true
            statusMessage = "Care store is unavailable."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            var task = OCKTask(
                id: makeTaskID(from: trimmedTitle),
                title: trimmedTitle,
                carePlanUUID: nil,
                schedule: makeDailySchedule(time: scheduleTime)
            )
            applySharedTaskConfiguration(
                to: &task,
                cardStyle: selectedCardStyle
            )
            _ = try await store.addTask(task)
            await onCreateSucceeded(message: "Task added successfully.")
        } catch {
            hasError = true
            statusMessage = "Failed to add task: \(error.localizedDescription)"
        }
    }

    func createHealthKitTask() async {
        guard !isProcessing else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            hasError = true
            statusMessage = "Task title is required."
            return
        }

        guard let healthKitStore = AppDelegateKey.defaultValue?.healthKitStore else {
            hasError = true
            statusMessage = "HealthKit store is unavailable."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let selectedStyle = selectedCardStyle
            let effectiveStyle = selectedStyle.healthKitCompatibleStyle
            var task = OCKHealthKitTask(
                id: makeTaskID(from: trimmedTitle),
                title: trimmedTitle,
                carePlanUUID: nil,
                schedule: makeDailySchedule(time: scheduleTime),
                healthKitLinkage: healthKitLinkage(for: effectiveStyle)
            )
            applySharedTaskConfiguration(
                to: &task,
                cardStyle: effectiveStyle
            )
            _ = try await healthKitStore.addTasksIfNotPresent([task])

            let status: String
            if selectedStyle == effectiveStyle {
                status = "HealthKitTask added successfully."
            } else {
                status = "HealthKitTask added. Card View changed to \(effectiveStyle.displayName)."
            }
            await onCreateSucceeded(message: status)
        } catch {
            hasError = true
            statusMessage = "Failed to add HealthKitTask: \(error.localizedDescription)"
        }
    }

    func refreshTasks() async {
        guard let appDelegate = AppDelegateKey.defaultValue else {
            hasError = true
            statusMessage = "App delegate is unavailable."
            return
        }

        guard let store = appDelegate.store else {
            hasError = true
            statusMessage = "Care store is unavailable."
            return
        }

        let healthKitStore = appDelegate.healthKitStore

        do {
            var query = OCKTaskQuery(for: Date())
            query.excludesTasksWithNoEvents = false

            var fetchedTasks = try await store.fetchAnyTasks(query: query)
            if let healthKitStore {
                let healthKitTasks = try await healthKitStore.fetchTasks(query: query)
                fetchedTasks.append(contentsOf: healthKitTasks)
            }

            var nextTaskCache: [String: any OCKAnyTask] = [:]
            let mappedTasks = fetchedTasks.map { task -> ManagedTaskItem in
                nextTaskCache[task.id] = task
                let rawTitle = task.title ?? ""
                let displayTitle = rawTitle.isEmpty ? task.id : rawTitle
                let rawAsset: String?
                if let careTask = task as? OCKTask {
                    rawAsset = careTask.asset
                } else if let healthTask = task as? OCKHealthKitTask {
                    rawAsset = healthTask.asset
                } else {
                    rawAsset = nil
                }
                let displayAsset = sanitizeAssetSymbol(rawAsset)
                let userInfo = taskUserInfo(for: task)
                let displayStyle = TaskCardStyle(
                    rawValue: userInfo?[Constants.taskCardStyleKey] ?? ""
                ) ?? .instructions
                let displayTaskType: ManagedTaskType
                if task is OCKHealthKitTask {
                    displayTaskType = .healthKitTask
                } else if task is OCKTask {
                    displayTaskType = .task
                } else {
                    displayTaskType = .unknown
                }
                return ManagedTaskItem(
                    id: task.id,
                    title: displayTitle,
                    assetSymbol: displayAsset,
                    cardStyle: displayStyle,
                    taskType: displayTaskType
                )
            }
            taskCache = nextTaskCache
            tasks = mappedTasks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

            if hasError {
                hasError = false
                statusMessage = ""
            }
        } catch {
            hasError = true
            statusMessage = "Failed to load tasks: \(error.localizedDescription)"
        }
    }

    func deleteTask(id: String) async {
        guard !isProcessing else { return }

        guard let appDelegate = AppDelegateKey.defaultValue else {
            hasError = true
            statusMessage = "App delegate is unavailable."
            return
        }
        guard let store = appDelegate.store else {
            hasError = true
            statusMessage = "Care store is unavailable."
            return
        }
        guard let anyTask = taskCache[id], let task = anyTask as? OCKTask else {
            hasError = true
            statusMessage = "Only Task entries are deletable here."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            _ = try await store.deleteTask(task)
            NotificationCenter.default.post(
                .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
            )
            hasError = false
            statusMessage = "Task deleted."
            await refreshTasks()
        } catch {
            hasError = true
            statusMessage = "Failed to delete task: \(error.localizedDescription)"
        }
    }

    func resetDraft() {
        title = ""
        instructions = ""
        assetSymbol = "checkmark.circle"
        selectedCardStyle = .instructions
        scheduleTime = Date()
        hasError = false
        statusMessage = ""
    }
}

private extension TaskManagementViewModel {
    func onCreateSucceeded(message: String) async {
        NotificationCenter.default.post(
            .init(name: Notification.Name(rawValue: Constants.shouldRefreshView))
        )
        hasError = false
        statusMessage = message
        title = ""
        instructions = ""
        assetSymbol = "checkmark.circle"
        selectedCardStyle = .instructions
        await refreshTasks()
    }

    func makeDailySchedule(time: Date) -> OCKSchedule {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: time
        )
        let startDate = Calendar.current.date(
            bySettingHour: components.hour ?? 8,
            minute: components.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()

        return OCKSchedule(
            composing: [
                OCKScheduleElement(
                    start: startDate,
                    end: nil,
                    interval: DateComponents(day: 1)
                )
            ]
        )
    }

    func makeTaskID(from title: String) -> String {
        let slug = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let sanitizedTitle = slug.isEmpty ? "custom_task" : slug
        let shortUUID = UUID().uuidString.prefix(8).lowercased()
        return "\(sanitizedTitle)_\(shortUUID)"
    }

    func sanitizeAssetSymbol(_ input: String?) -> String {
        let trimmed = (input ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "checkmark.circle" : trimmed
    }

    func taskUserInfo(for task: any OCKAnyTask) -> [String: String]? {
        if let careTask = task as? OCKTask {
            return careTask.userInfo
        }
        if let healthTask = task as? OCKHealthKitTask {
            return healthTask.userInfo
        }
        return nil
    }

    func healthKitLinkage(for style: TaskCardStyle) -> OCKHealthKitLinkage {
        switch style {
        case .labeledValue:
            return OCKHealthKitLinkage(
                quantityIdentifier: .restingHeartRate,
                quantityType: .discrete,
                unit: HKUnit.count().unitDivided(by: .minute())
            )
        default:
            return OCKHealthKitLinkage(
                quantityIdentifier: .stepCount,
                quantityType: .cumulative,
                unit: .count()
            )
        }
    }

    func applySharedTaskConfiguration(
        to task: inout OCKTask,
        cardStyle: TaskCardStyle
    ) {
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            task.instructions = trimmedInstructions
        }
        task.asset = sanitizeAssetSymbol(assetSymbol)
        task.userInfo = [
            Constants.taskCardStyleKey: cardStyle.rawValue,
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]
    }

    func applySharedTaskConfiguration(
        to task: inout OCKHealthKitTask,
        cardStyle: TaskCardStyle
    ) {
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            task.instructions = trimmedInstructions
        }
        task.asset = sanitizeAssetSymbol(assetSymbol)
        task.userInfo = [
            Constants.taskCardStyleKey: cardStyle.rawValue,
            Constants.taskDomainKey: Constants.thyroidDomainValue
        ]
    }
}

struct ManagedTaskItem: Identifiable {
    let id: String
    let title: String
    let assetSymbol: String
    let cardStyle: TaskCardStyle
    let taskType: ManagedTaskType
}
