import Pororoca

enum List500Screen {
    struct State: ScreenState {
        static let schema: [String: StateType] = ["items": .array, "highlight": .bool]
    }

    enum Action: String, ScreenAction { case selectRow }

    static let document = Screen("list-500", state: State.self, actions: Action.self) { state, _ in
        ScrollView {
            LazyColumn(spacing: .space("sm")) {
                ForEach(state.items, key: "id") { item in
                    HStack(spacing: .space("md")) {
                        Icon("figure.strengthtraining.traditional", size: 22, weight: .semibold)
                            .foreground(.color("primary"))
                            .frame(width: .points(32), height: .points(32))
                        VStack(spacing: .space("xs"), alignment: .leading) {
                            Text(item.title).font(.system(size: 16, weight: .semibold)).foreground(.color("text"))
                            Text(item.subtitle).font(.system(size: 13)).foreground(.color("textSecondary"))
                        }
                        Spacer(minLength: .points(0))
                        If(state.highlight) { Icon("sparkles", size: 12).foreground(.color("accent")) }
                        Text(item.value).font(.system(size: 14, weight: .medium, design: .monospaced)).foreground(.color("text"))
                    }
                    .padding(.all, .space("md"))
                    .background(.color(.color("surface")))
                    .cornerRadius(.radius("md"))
                }
            }
            .padding(.all, .space("md"))
        }
        .background(.color(.color("background")))
    }

    static let items: [List500Item] = (0..<500).map {
        List500Item(id: $0, title: "Exercise \($0 + 1)", subtitle: "4 sets · 10 reps", value: "\(100 + $0) kg")
    }

    static var valueItems: Value {
        .array(items.map { item in
            .object(["id": .number(Double(item.id)), "title": .string(item.title), "subtitle": .string(item.subtitle), "value": .string(item.value)])
        })
    }
}

struct List500Item: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let value: String
}

@MainActor
enum List500Host {
    static let value = ScreenHost(
        capabilities: HostCapabilities(List500Screen.document.requires),
        tokens: PaywallHost.value.tokens,
        localizer: PaywallStrings()
    )
}
