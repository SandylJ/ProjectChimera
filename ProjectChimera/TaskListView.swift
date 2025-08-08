import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    var user: User
    @Binding var didLevelUp: Bool
    @Binding var didEvolve: Bool
    
    @State private var tasks: [Task] = []
    
    @State private var showingAddTaskView = false
    @State private var taskCompletedTrigger = false // For haptics

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Daily Tasks").font(.title2).bold().padding(.leading)
                Spacer()
                Button { showingAddTaskView.toggle() } label: { Image(systemName: "plus") }
                .padding(.trailing)
            }
            
            if tasks.isEmpty {
                ContentUnavailableView("No tasks yet!", systemImage: "checklist", description: Text("Add a new task to begin your journey."))
            } else {
                List {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { completeTask(task) } label: { Label("Complete", systemImage: "checkmark") }
                                .tint(.green)
                            }
                    }
                    .onDelete(perform: deleteTask)
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddTaskView) { AddTaskView() }
        .sensoryFeedback(.success, trigger: taskCompletedTrigger)
        .onAppear {
            loadTasks()
        }
    }
    
    private func loadTasks() {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate<Task> { !$0.isCompleted },
            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
        )
        do {
            tasks = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
            tasks = []
        }
    }
    
    private func completeTask(_ task: Task) {
        withAnimation {
            if !task.isCompleted {
                task.isCompleted = true
                task.completionDate = .now
                
                // FIX: Correctly handle the tuple returned by the function.
                let result = GameLogicManager.shared.awardXP(for: task, to: user)
                if result.didLevelUp {
                    didLevelUp = true
                    SensoryFeedbackManager.shared.trigger(for: .levelUp)
                }
                if result.didEvolve {
                    didEvolve = true
                    SensoryFeedbackManager.shared.trigger(for: .chimeraEvolved)
                }
                
                // Trigger sound and haptics
                SensoryFeedbackManager.shared.trigger(for: .taskCompleted)
                taskCompletedTrigger.toggle()
                
                // Reload tasks after completion
                loadTasks()
            }
        }
    }
    
    private func deleteTask(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(tasks[index]) }
            loadTasks()
        }
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    @Bindable var task: Task
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(task.title).font(.headline)
                    Text("Stat: \(task.associatedStat.rawValue.capitalized)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if !(task.subTasks?.isEmpty ?? true) {
                    Image(systemName: "checklist").foregroundColor(.accentColor)
                }
            }
            
            if let subTasks = task.subTasks, !subTasks.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(subTasks) { subTask in SubTaskRowView(subTask: subTask) }
                }
                .padding(.leading).padding(.top, 5)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Sub-Task Row View
struct SubTaskRowView: View {
    @Bindable var subTask: SubTask
    @State private var subTaskCompletedTrigger = false // For haptics
    
    var body: some View {
        HStack {
            Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundColor(subTask.isCompleted ? .green : .secondary)
            Text(subTask.title)
                .strikethrough(subTask.isCompleted)
                .foregroundColor(subTask.isCompleted ? .secondary : .primary)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                subTask.isCompleted.toggle()
                SensoryFeedbackManager.shared.trigger(for: .subTaskCompleted)
                subTaskCompletedTrigger.toggle()
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: subTaskCompletedTrigger)
    }
}

// MARK: - Add Task View (Unchanged from Phase 1)
struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var selectedStat: ChimeraStat = .discipline
    @State private var selectedDifficulty: TaskDifficulty = .easy
    @State private var isDecomposing = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Name (e.g., Clean the kitchen)", text: $title)
                    Picker("Associated Stat", selection: $selectedStat) {
                        ForEach(ChimeraStat.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(TaskDifficulty.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
                Section(header: Text("AI Assistant")) {
                    Button(action: decomposeTask) {
                        HStack {
                            Text("Decompose with AI")
                            if isDecomposing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(title.isEmpty || isDecomposing)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { saveTask(); dismiss() }.disabled(title.isEmpty) }
            }
        }
    }
    
    private func saveTask(subTaskTitles: [String]? = nil) {
        let newTask = Task(title: title, difficulty: selectedDifficulty, associatedStat: selectedStat)
        if let titles = subTaskTitles {
            newTask.subTasks = titles.map { SubTask(title: $0) }
        }
        modelContext.insert(newTask)
    }
    
    private func decomposeTask() {
        isDecomposing = true
        AIManager.shared.decompose(taskTitle: title) { subTaskTitles in
            saveTask(subTaskTitles: subTaskTitles)
            isDecomposing = false
            dismiss()
        }
    }
}
