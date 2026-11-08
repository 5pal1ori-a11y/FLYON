import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        ZStack {
            Theme.headerGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("LogoMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .foregroundStyle(.white)

                Text("FLYON")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(.white)
                    .padding(.top, 18)

                Text("항공권 가격의 흐름을 읽어 드려요")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 6)

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        auth.handle(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(Capsule())

                    if let message = auth.errorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.yellow)
                    }

                    #if DEBUG
                    Button("개발용 둘러보기") { auth.signInForDebug() }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                    #endif

                    Text("계속하면 이용약관과 개인정보처리방침에 동의한 것으로 봅니다.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

#Preview {
    LoginView().environment(AuthManager())
}
