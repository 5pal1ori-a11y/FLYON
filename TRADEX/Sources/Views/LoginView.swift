import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(Session.self) private var session
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 0) {
            Spacer()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 72)
                .foregroundStyle(.primary)
            Text("TRADEX")
                .font(.system(size: 34, weight: .heavy))
                .tracking(4)
                .padding(.top, 20)
            Text("실시간 시세로 연습하는 코인 모의투자")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                benefit("gift", "가입하면 \(TradexRules.signupBonus) TRADEX 지급",
                        "1 TRADEX = 모의투자금 \(Fmt.krw(TradexRules.krwPerTradex))")
                benefit("bolt", "실제 거래소 실시간 시세", "가격·등락률이 실제와 똑같이 움직여요")
                benefit("shield", "실제 돈은 전혀 쓰지 않아요", "가상 자산으로만 거래하는 연습용 앱이에요")
            }
            .card()
            .padding(.horizontal, 20)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                session.handleApple(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            #if DEBUG
            Button("개발용 로그인 (디버그 빌드 전용)") { session.signInAsDeveloper() }
                .font(.footnote)
                .padding(.top, 12)
            #endif

            Text("TRADEX는 모의투자 서비스이며 실제 가상자산 거래·투자 권유를 하지 않습니다.\nTRADEX와 모의투자금은 현금이나 실제 자산으로 바꿀 수 없습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .alert("알림", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private func benefit(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct WelcomeBonusView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false

    var body: some View {
        VStack(spacing: 18) {
            Image("Logo")
                .resizable().scaledToFit()
                .frame(height: 56)
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)
            Text("가입을 축하해요!")
                .font(.title2.bold())
            Text("\(TradexRules.signupBonus) TRADEX")
                .font(.system(size: 40, weight: .heavy))
                .monospacedDigit()
            Text("자산 탭에서 TRADEX를 업비트·빗썸 지갑에 충전해\n바로 거래를 시작해 보세요.\n1 TRADEX = \(Fmt.krw(TradexRules.krwPerTradex))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("시작하기") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .padding(24)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true } }
    }
}
