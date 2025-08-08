import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var currentStep: OnboardingStep = .welcome
    
    @State private var chimeraName: String = ""
    @State private var firstTaskTitle: String = ""
    
    var body: some View {
        VStack {
            // A view that switches based on the current onboarding step.
            switch currentStep {
            case .welcome:
                WelcomeStepView(onContinue: {
                    withAnimation { currentStep = .nameChimera }
                })
            case .nameChimera:
                NameChimeraStepView(chimeraName: $chimeraName, onContinue: {
                    withAnimation { currentStep = .firstTask }
                })
            case .firstTask:
                FirstTaskStepView(taskTitle: $firstTaskTitle, onContinue: {
                    withAnimation { currentStep = .finish }
                })
            case .finish:
                FinishStepView(onComplete: {
                    // Create the user and their first task, then complete onboarding.
                    createInitialUserAndTask()
                    OnboardingManager.shared.completeOnboarding()
                })
            }
        }
        .animation(.default, value: currentStep)
    }
    
    private func createInitialUserAndTask() {
        // Create the new user and set their Chimera's name.
        let newUser = User(username: "PlayerOne")
        if let chimera = newUser.chimera {
            chimera.name = self.chimeraName.isEmpty ? "Chimera" : self.chimeraName
        }
        modelContext.insert(newUser)
        
        // Create the user's first task if a title was provided.
        if !firstTaskTitle.isEmpty {
            let firstTask = UserTask(
                title: firstTaskTitle,
                difficulty: .easy,
                associatedStat: .intellect
            )
            modelContext.insert(firstTask)
        }
    }
}

// Enum to represent the steps in the onboarding flow.
enum OnboardingStep {
    case welcome, nameChimera, firstTask, finish
}

// MARK: - Onboarding Step Subviews (Unchanged)

struct WelcomeStepView: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to\nProject Chimera")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)
            
            Image(systemName: "egg.fill")
                .font(.system(size: 100))
                .foregroundColor(.gray)
            
            Text("Your personal journey of growth is about to begin. Let's hatch your companion.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Begin", action: onContinue)
                .buttonStyle(JuicyButtonStyle())
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
}

struct NameChimeraStepView: View {
    @Binding var chimeraName: String
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("A companion appears!")
                .font(.largeTitle).bold()
            
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.accentColor)
            
            Text("Every great companion needs a name. What will you call yours?")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Chimera's Name", text: $chimeraName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Next", action: onContinue)
                .buttonStyle(JuicyButtonStyle())
                .disabled(chimeraName.isEmpty)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
}

struct FirstTaskStepView: View {
    @Binding var taskTitle: String
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Your First Intention")
                .font(.largeTitle).bold()
            
            Image(systemName: "target")
                .font(.system(size: 100))
                .foregroundColor(.accentColor)
            
            Text("Your Chimera grows when you do. Set a simple, achievable goal for tomorrow to take your first step.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("e.g., Make my bed", text: $taskTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Next", action: onContinue)
                .buttonStyle(JuicyButtonStyle())
                .disabled(taskTitle.isEmpty)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
}

struct FinishStepView: View {
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("You're All Set!")
                .font(.largeTitle).bold()
            
            Image(systemName: "sparkles")
                .font(.system(size: 100))
                .foregroundColor(.yellow)
            
            Text("Your journey begins now. Complete your daily tasks to help your Chimera evolve.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Enter the App", action: onComplete)
                .buttonStyle(JuicyButtonStyle())
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
    }
}

// FIX: Removed the duplicate JuicyButtonStyle from this file.

#Preview {
    OnboardingView()
        .modelContainer(for: [User.self, Task.self], inMemory: true)
}