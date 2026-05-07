import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AccountViewModel

    @State private var handle = ""
    @State private var appPassword = ""
    @State private var isSecured = true
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case handle
        case password
    }

    private var canSubmit: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !appPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Handle", text: $handle)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .handle)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }

                    HStack {
                        if isSecured {
                            SecureField("App Password", text: $appPassword)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    submit()
                                }
                        } else {
                            TextField("App Password", text: $appPassword)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit {
                                    submit()
                                }
                        }

                        Button(action: { isSecured.toggle() }) {
                            Image(systemName: isSecured ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(isSecured ? "Show password" : "Hide password")
                    }
                } header: {
                    Text("Bluesky Account")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use an app password from Bluesky Settings → App Passwords. Don't use your main account password.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let error = viewModel.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Add") {
                            submit()
                        }
                        .disabled(!canSubmit)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                focusedField = .handle
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        Task {
            await viewModel.addAccount(handle: handle, appPassword: appPassword)
            if viewModel.errorMessage == nil {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    AddAccountView(viewModel: AccountViewModel())
}
