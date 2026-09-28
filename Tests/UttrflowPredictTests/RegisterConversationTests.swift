import Testing

@testable import UttrflowPredict

/// One moment on a screen: what the field calls itself, what is around it, and whether it is a conversation.
struct ScreenMoment: Sendable, CustomTestStringConvertible {
    /// What the row is named after in a failure.
    let name: String
    /// The field's own accessibility name.
    let field: String?
    /// The screen's lines as the collector reads them, in reading order.
    let screen: [String]
    /// Whether the line typed here is a reply in a conversation.
    let isChat: Bool

    /// What a failure is named after.
    var testDescription: String { name }
}

/// A web page's navigation, shared by the pages below.
private let navigation = [
    "Skip to main content", "Home", "Products", "Pricing", "Docs", "Blog", "Community", "Sign in", "Search",
]

/// Pages whose short lines are menus, links and buttons, beside chats that must stay chats.
private let moments: [ScreenMoment] = [
    ScreenMoment(
        name: "blog comment box", field: "Comment",
        screen: navigation + [
            "Why incremental builds get slower over time", "Posted in Engineering · 9 min read",
            "The fix was not clever. We narrowed the inputs and rebuild times fell back under 15 seconds.",
            "Share", "Copy link", "12 comments", "dev_ops_42", "3 hours ago",
            "We hit exactly this with generated code.", "Reply", "Report", "maria_k", "1 hour ago",
            "Great write-up.", "Reply", "Report", "Leave a comment",
        ], isChat: false),
    ScreenMoment(
        name: "issue comment box", field: "Add a comment",
        screen: [
            "example-org / example-repo", "Code", "Issues 214", "Pull requests 31", "Actions", "Settings",
            "Crash when opening a symlinked workspace folder #1873", "Open",
            "Steps to reproduce: open the symlink from the start screen and wait.",
            "Expected: the project opens. Actual: the app quits.", "bug", "needs-triage",
            "commented yesterday", "Same here on 4.2.0.", "commented 3 hours ago", "Attached.",
            "Write", "Preview", "Markdown is supported",
        ], isChat: false),
    ScreenMoment(
        name: "web mail body", field: "Message Body",
        screen: [
            "Mail", "Compose", "Inbox 3,412", "Starred", "Snoozed", "Sent", "Drafts 12",
            "Quarterly planning follow-up", "Jordan", "to me", "Sep 12, 2026, 4:18 PM",
            "Could you send over the revised timeline by Friday?", "Best, Jordan", "Reply", "Reply all",
            "Forward", "To", "jordan@example.com", "Subject",
        ], isChat: false),
    ScreenMoment(
        name: "shop search box", field: "Search products",
        screen: ["Brightleaf Store", "Men", "Women", "Kids", "Sale", "Gift cards", "Basket (2)", "New in"],
        isChat: false),
    ScreenMoment(
        name: "docs feedback form", field: "Tell us how we can improve this page",
        screen: navigation + [
            "Installation", "Quick start", "Configuration", "Plugins", "Deployment", "FAQ",
            "Was this page helpful?", "Yes", "No", "Submit",
        ], isChat: false),
    ScreenMoment(
        name: "news comment box", field: "Write a comment",
        screen: [
            "Example News", "World", "Business", "Technology", "Sport", "Subscribe",
            "City opens new metro line", "By a staff reporter · 14 September 2026",
            "Trains will run every five minutes from 6:00 to 23:00.", "Most read",
            "Heatwave warning extended",
            "Join the conversation", "342 comments",
        ], isChat: false),
    ScreenMoment(
        name: "contact form message box", field: "Your message",
        screen: navigation + ["Contact us", "Name", "Email", "We reply within two working days.", "Send"],
        isChat: false),
    ScreenMoment(
        name: "mail headers are not speakers", field: "Message body",
        screen: ["From: Sam", "To: me", "Subject: August invoice", "Could you share the invoice?"],
        isChat: false),
    ScreenMoment(
        name: "task list with repeated field labels", field: "Notes",
        screen: ["Owner: Dev team", "Due: Friday", "Owner: Design", "Due: Monday"], isChat: false),
    ScreenMoment(
        name: "bug template repeated per report", field: "Description",
        screen: [
            "Expected: the file saves", "Actual: nothing happens", "Expected: a warning",
            "Actual: the app quits",
        ], isChat: false),
    ScreenMoment(
        name: "quoted mail thread headers", field: nil,
        screen: [
            "From: Sam", "To: Alex", "Subject: Invoice", "Sounds good.", "From: Alex", "To: Sam",
            "Subject: Invoice", "Could you share it?",
        ], isChat: false),
    ScreenMoment(
        name: "named turns in a chat", field: "Message",
        screen: [
            "Priya: where did the log go?", "Me: in dist/, one sec", "Priya: found it, thanks!",
            "Priya: are you coming tonight?",
        ], isChat: true),
    ScreenMoment(
        name: "named turns under a web chat's sidebar", field: nil,
        screen: navigation + [
            "Neha (PM): Standup moved to 10:30 tomorrow, please confirm.", "Arjun: Confirmed.",
            "Neha (PM): Can someone own the staging deploy?",
        ], isChat: true),
    ScreenMoment(
        name: "web chat whose messages carry stamps", field: "Type a message",
        screen: [
            "Chats", "Search or start a new chat", "Unread", "Rahul", "Family",
            "Messages in chat with Priya",
            "message, Meeting mei ho?, 3Septemberat6:38\u{202F}PM, Received from Priya",
            "Your message, Haan, 3Septemberat6:41\u{202F}PM, Sent to Priya, Delivered",
            "message, Ok, 3Septemberat6:55\u{202F}PM, Received from Priya",
        ], isChat: true),
    ScreenMoment(
        name: "team chat with names and times on their own lines", field: "Message #platform",
        screen: [
            "Channels", "# general", "# platform", "Direct messages", "Neha", "10:31 AM",
            "Standup moved, please confirm.", "Arjun", "10:33 AM", "Confirmed.",
        ], isChat: true),
]

@Suite("A conversation is people taking turns, not a page's short lines")
struct RegisterConversationTests {
    @Test("Each screen reads as a conversation exactly when people take turns on it.", arguments: moments)
    func screensAreClassified(moment: ScreenMoment) {
        let situation = GenerationSituation(
            application: "Browser", field: moment.field, surroundings: moment.screen.joined(separator: "\n"),
            isMultiline: true)
        let register = Register.infer(from: situation, typed: "Thanks for the")
        #expect(register.isConversational == moment.isChat)
        #expect((register.kind == "reply") == moment.isChat)
        #expect(
            register.hints.contains("a conversation is on screen and the line answers its last message")
                == moment.isChat)
    }

    @Test("A speaker is a short name before a colon and a space, never a time, a sentence or a symbol.")
    func speakersAreShortNames() {
        #expect(Register.speaker(of: "Priya: on my way") == "Priya")
        #expect(Register.speaker(of: "Neha (PM): confirmed") == "Neha (PM)")
        #expect(Register.speaker(of: "Support bot:") == "Support bot")
        #expect(Register.speaker(of: "Standup moved to 10:30 tomorrow") == nil)
        #expect(Register.speaker(of: "Steps to reproduce the crash: open it") == nil)
        #expect(Register.speaker(of: "12: twelve") == nil)
        #expect(Register.speaker(of: ": nothing") == nil)
        #expect(Register.speaker(of: "a#b: symbols") == nil)
        #expect(Register.speaker(of: String(repeating: "a", count: 40) + ": long") == nil)
        #expect(Register.speaker(of: "no colon") == nil)
        #expect(!Register.hasSpeakerTurns(["A: one", "B: two", "C: three"]))
        #expect(!Register.hasSpeakerTurns(["A: one", "A: two", "A: three"]))
        #expect(Register.hasSpeakerTurns(["A: one", "B: two", "A: three"]))
    }

    @Test("A field label is never a speaker.", arguments: Register.fieldLabels.sorted())
    func fieldLabelsAreNotSpeakers(label: String) {
        let capitalised = label.prefix(1).uppercased() + label.dropFirst()
        #expect(Register.speaker(of: "\(capitalised): value") == nil)
        #expect(Register.speaker(of: "\(label.uppercased()): value") == nil)
    }

    @Test(
        "A label headed by a field's word is a field, not a speaker.",
        arguments: [
            "Expected result", "Actual result", "Expected behavior", "Actual behavior", "Steps to reproduce",
            "Due date", "Start date", "Assigned to", "Reported by", "Created at",
        ])
    func multiWordFieldLabelsAreNotSpeakers(label: String) {
        #expect(Register.speaker(of: "\(label): value") == nil)
    }

    @Test("A bug report template repeated twice reads as a record, not two speakers taking turns.")
    func bugReportTemplateIsNotAConversation() {
        let report = [
            "Expected result: the list scrolls", "Actual result: it jumps to the top",
            "Expected result: the badge clears", "Actual result: it stays",
        ]
        #expect(!Register.isConversation(report))
        #expect(
            Register.isConversation([
                "Priya: on my way", "Neha (PM): confirmed", "Priya: see you", "Neha (PM): ok",
            ]))
    }

    @Test("A time of day is one or two digits, a colon and two digits, wherever it sits in the line.")
    func clockTimesAreFound() {
        #expect(Register.showsClockTime("10:31 AM"))
        #expect(Register.showsClockTime("3Septemberat6:38\u{202F}PM"))
        #expect(Register.showsClockTime("at 9:05"))
        #expect(!Register.showsClockTime("3 hours ago"))
        #expect(!Register.showsClockTime("Ratio 123:45"))
        #expect(!Register.showsClockTime("1:2"))
        #expect(!Register.showsClockTime("10:305"))
        #expect(!Register.showsClockTime(":30"))
    }

    @Test("A message composer names itself so; a mail's body or subject does not count.")
    func composersNameThemselves() {
        for name in ["Message", "Type a message", "Message #platform", "Write a message", "Chat input"] {
            #expect(Register.namesMessageComposer(name), "\(name)")
        }
        for name in ["Message Body", "Message subject", "Comment", "Search", nil] {
            #expect(!Register.namesMessageComposer(name), "\(name ?? "nil")")
        }
    }
}
