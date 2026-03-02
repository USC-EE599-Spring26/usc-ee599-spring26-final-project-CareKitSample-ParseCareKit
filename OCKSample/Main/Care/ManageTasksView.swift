//
//  ManageTasksView.swift
//  OCKSample
//
//  Created by Faye.
//

import SwiftUI
import CareKitStore
import os.log

// View

struct ManageTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManageTasksViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading tasks…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "tray",
                        description: Text("Add a task from the Profile screen first.")
                    )
                } else {
                    List {
                        ForEach(viewModel.tasks.indices, id: \.self) { index in
                            let task = viewModel.tasks[index]
                            HStack(spacing: 12) {
                                // SF Symbol asset if set
                                if let asset = task.asset,
                                   !asset.isEmpty,
                                   UIImage(systemName: asset) != nil {
                                    Image(systemName: asset)
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 30)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(viewModel.displayTitle(for: task))
                                        .font(.headline)
                                    Text(task.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            Task { await viewModel.delete(at: offsets) }
                        }
                    }
                }
            }
            .navigationTitle("Manage Tasks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .alert("Could not delete task", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

// ViewModel

@MainActor
final class ManageTasksViewModel: ObservableObject {

    @Published var tasks: [any OCKAnyTask] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let appDelegate = AppDelegateKey.defaultValue else { return }

        do {
            // Fetch from both stores
            var query = OCKTaskQuery(for: Date())
            query.excludesTasksWithNoEvents = false
            let regularTasks = try await appDelegate.store.fetchAnyTasks(query: query)
            let hkTasks      = try await appDelegate.healthKitStore.fetchAnyTasks(query: query)

            let allTasks = (regularTasks + hkTasks)
                .sorted {
                    displayTitle(for: $0).localizedCaseInsensitiveCompare(
                        displayTitle(for: $1)
                    ) == .orderedAscending
                }
            tasks = allTasks
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func delete(at offsets: IndexSet) async {
        guard let appDelegate = AppDelegateKey.defaultValue else { return }
        let toDelete = offsets.map { tasks[$0] }

        do {
            // Separate by store type
            let regular  = toDelete.compactMap { $0 as? OCKTask }
            let hkTasks  = toDelete.compactMap { $0 as? OCKHealthKitTask }

            if !regular.isEmpty {
                _ = try await appDelegate.store.deleteTasks(regular)
            }
            if !hkTasks.isEmpty {
                _ = try await appDelegate.healthKitStore.deleteTasks(hkTasks)
            }

            tasks.remove(atOffsets: offsets)
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: Constants.shouldRefreshView),
                object: nil
            )
            Logger.profile.info("Deleted \(toDelete.count) task(s)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func displayTitle(for task: any OCKAnyTask) -> String {
        if let t = task as? OCKTask           { return t.title   ?? t.id }
        if let h = task as? OCKHealthKitTask  { return h.title   ?? h.id }
        return task.id
    }
}

#Preview {
    ManageTasksView()
}
