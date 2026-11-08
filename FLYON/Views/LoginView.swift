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
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.white)
                    .appear()
                Text("FLYON")
                    .font(.app(36, .heavy))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                    .appear(delay: 0.08)
                Text("항공권 가격, 흐름으로 읽다")
                    .font(.app(15, .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 8)
                    .appear(delay: 0.16)
                Spacer()

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        auth.handle(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(Capsule())

                    if let message = auth.errorMessage {
                        Text(message)
                            .font(.app(13))
                            .foregroundStyle(.yellow)
                    }

                    #if DEBUG
                    Button("개발용 둘러보기") { auth.signInForDebug() }
                        .font(.app(13))
                        .foregroundStyle(.white.opacity(0.7))
                    #endif

                    Text("계속하면 이용약관과 개인정보처리방침에 동의하게 됩니다")
                        .font(.app(11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .appear(delay: 0.25)
            }
        }
    }
}
