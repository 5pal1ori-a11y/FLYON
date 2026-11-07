import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("LogoMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .foregroundStyle(.primary)

            Text("FLYON")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .tracking(4)
                .padding(.top, 16)

            Text("항공권 가격의 흐름을 읽어 드려요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    auth.handle(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let message = auth.errorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.expensive)
                }

                #if DEBUG
                Button("개발용 둘러보기") { auth.signInForDebug() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #endif

                Text("계속하면 이용약관과 개인정보처리방침에 동의한 것으로 봅니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.screenBackground.ignoresSafeArea())
    }
}

#Preview {
    LoginView().environment(AuthManager())
}
