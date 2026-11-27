import SwiftUI

/// 오픈소스 라이선스 고지 (코인 아이콘) — MIT 라이선스는 앱 안에 고지문을 포함해야 한다.
struct OpenSourceView: View {
    private let items: [(String, String)] = [
        ("web3icons", "MIT License · Copyright (c) 0xa3k5"),
        ("@iconify-json/token-branded", "MIT License (원본 web3icons)"),
        ("@ledgerhq/crypto-icons-ui", "MIT License · Copyright (c) 2022 Ledger"),
        ("cryptocurrency-icons", "CC0 1.0"),
        ("Fluent Emoji (3D 아이콘)", "MIT License · Copyright (c) Microsoft Corporation"),
    ]

    private let mit = """
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """

    var body: some View {
        List {
            Section {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0).font(.subheadline.weight(.semibold))
                        Text(item.1).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("아이콘")
            } footer: {
                Text("각 코인 로고는 해당 프로젝트의 상표일 수 있으며, 해당 코인을 표시하는 용도로만 사용해요.")
            }
            Section("MIT License") {
                Text(mit).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("오픈소스 라이선스")
    }
}
