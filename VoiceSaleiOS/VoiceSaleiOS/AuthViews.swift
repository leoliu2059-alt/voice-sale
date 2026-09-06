import SwiftUI

struct LoginSheetView: View {
    @EnvironmentObject private var auth: SupabaseAuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var isSigningUp = false
    @State private var isSendingReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(AppTheme.green)
                        Text("语销镜")
                            .font(.largeTitle.weight(.black))
                        Text("登录后同步云端复盘与音频")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.top, 18)

                    VStack(spacing: 12) {
                        TextField("邮箱", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("密码", text: $password)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            isSendingReset = true
                            Task {
                                _ = await auth.sendPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                                isSendingReset = false
                            }
                        } label: {
                            Text(isSendingReset ? "发送中…" : "忘记密码？")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.green)
                        .disabled(isSigningIn || isSigningUp || isSendingReset || email.isEmpty)

                        if let message = auth.lastErrorMessage, !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let message = auth.lastInfoMessage, !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            isSigningIn = true
                            Task {
                                let ok = await auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                isSigningIn = false
                                if ok { dismiss() }
                            }
                        } label: {
                            Label(isSigningIn ? "登录中…" : "登录", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.green)
                        .disabled(isSigningIn || isSigningUp || isSendingReset || email.isEmpty || password.isEmpty)

                        Button {
                            isSigningUp = true
                            Task {
                                let result = await auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                isSigningUp = false
                                if case .signedIn = result { dismiss() }
                            }
                        } label: {
                            Text(isSigningUp ? "注册中…" : "注册新账号")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.green)
                        .disabled(isSigningIn || isSigningUp || isSendingReset || email.isEmpty || password.isEmpty)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct ResetPasswordSheetView: View {
    @EnvironmentObject private var auth: SupabaseAuthStore
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(AppTheme.green)
                        Text("设置新密码")
                            .font(.title.weight(.black))
                        Text("新密码生效后，可以继续用邮箱和密码登录。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 18)

                    VStack(spacing: 12) {
                        SecureField("新密码", text: $password)
                            .textFieldStyle(.roundedBorder)
                        SecureField("再次输入新密码", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)

                        if let message = validationMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let message = auth.lastErrorMessage, !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button {
                        isUpdating = true
                        Task {
                            _ = await auth.updatePassword(password)
                            isUpdating = false
                        }
                    } label: {
                        Label(isUpdating ? "更新中…" : "更新密码", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.green)
                    .disabled(isUpdating || !canSubmit)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var canSubmit: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private var validationMessage: String? {
        guard !password.isEmpty || !confirmPassword.isEmpty else { return nil }
        if password.count < 6 { return "密码至少 6 位。" }
        if password != confirmPassword { return "两次输入的密码不一致。" }
        return nil
    }
}
