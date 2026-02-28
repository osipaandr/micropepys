import SwiftUI
import MicropepysCore

struct ChecklistWidgetView: View {
    @EnvironmentObject private var manager: ChecklistManager
    @State private var newTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(manager.items) { item in
                HStack(spacing: 8) {
                    Button {
                        manager.toggle(id: item.id)
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)
                    .tint(.accentColor)
                    .accessibilityLabel(item.isCompleted ? "Mark as incomplete" : "Mark as complete")
                    
                    TextField(
                        "Item",
                        text: Binding(
                            get: { item.title },
                            set: { manager.update(id: item.id, title: $0) }
                        )
                    )
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    
                    Button {
                        manager.remove(id: item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete item")
                }
            }
            
            HStack {
                TextField("Add item", text: $newTitle)
                Button {
                    if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        manager.add(title: newTitle)
                        newTitle = ""
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .tint(.accentColor)
                .accessibilityLabel("Add item")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2))
                )
                .shadow(radius: 4, y: 2)
        )
    }
}

#Preview {
    ChecklistWidgetView()
        .environmentObject(ChecklistManager())
        .padding()
}
