import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @State private var fieldToAdd: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Reorder Sort Order")
                .font(.headline)
            Text("Reorder sorts tracks by these fields in priority order (top = highest priority). This applies to the Reorder tab.")
                .foregroundStyle(.secondary)

            List {
                ForEach(settings.sortFields.indices, id: \.self) { idx in
                    HStack {
                        Text(AppSettings.fieldLabels[settings.sortFields[idx].field] ?? settings.sortFields[idx].field)
                            .frame(width: 100, alignment: .leading)

                        Picker("", selection: $settings.sortFields[idx].descending) {
                            Text("Ascending").tag(false)
                            Text("Descending").tag(true)
                        }
                        .labelsHidden()
                        .frame(width: 140)

                        Spacer()

                        Button {
                            moveUp(idx)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(idx == 0)

                        Button {
                            moveDown(idx)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(idx == settings.sortFields.count - 1)

                        Button(role: .destructive) {
                            settings.sortFields.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .disabled(settings.sortFields.count <= 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 220)

            HStack {
                Picker("Add field", selection: $fieldToAdd) {
                    ForEach(unusedFields, id: \.self) { field in
                        Text(AppSettings.fieldLabels[field] ?? field).tag(field)
                    }
                }
                .frame(maxWidth: 250)
                .disabled(unusedFields.isEmpty)

                Button("Add") {
                    settings.sortFields.append(SortField(field: fieldToAdd, descending: false))
                    fieldToAdd = unusedFields.first ?? ""
                }
                .disabled(unusedFields.isEmpty || fieldToAdd.isEmpty)
            }

            Button("Reset to Default (Artist, Album, Name)") {
                settings.sortFields = AppSettings.defaultSortFields
            }

            Spacer()

            Text("Current order: \(settings.sortSpec)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            fieldToAdd = unusedFields.first ?? ""
        }
    }

    private var unusedFields: [String] {
        let used = Set(settings.sortFields.map(\.field))
        return AppSettings.availableFields.filter { !used.contains($0) }
    }

    private func moveUp(_ idx: Int) {
        guard idx > 0 else { return }
        settings.sortFields.swapAt(idx, idx - 1)
    }

    private func moveDown(_ idx: Int) {
        guard idx < settings.sortFields.count - 1 else { return }
        settings.sortFields.swapAt(idx, idx + 1)
    }
}
