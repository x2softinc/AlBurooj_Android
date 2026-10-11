import SwiftUI

// TEMPORARY in-app Terms of Use (EULA).
//
// This screen renders the agreement natively until a hosted terms page is
// available. Once a URL exists, give LegalDocument.termsOfUse a
// hostedURLString and point the Settings row at LegalDocumentView instead.
//
// NOTE: The text below is a template and must be reviewed by the developer /
// legal counsel before shipping. Fill in the bracketed placeholders and adjust
// any wording to match the app's actual features and data practices.

struct EULAView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerBlock
                ForEach(Self.sections) { section in
                    sectionView(section)
                }
                Divider()
                effectiveDateBlock
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(LegalDocument.termsOfUse.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Section: Identifiable {
        let id: String
        let heading: String
        let paragraphs: [String]
    }

    private static let sections: [Section] = [
        Section(
            id: "license",
            heading: "1. License",
            paragraphs: [
                "Subject to the terms of this Agreement, X2Soft Inc. grants you a limited, non-exclusive, non-transferable, revocable license to install and use Al-Burooj Iqama (the App) on Apple-branded devices that you own or control, solely for your personal, non-commercial use.",
                "Apple Inc. is not a party to this Agreement and has no obligation to provide maintenance or support for the App. This license is also subject to the Usage Rules of the Apple Media Services Terms and Conditions."
            ]
        ),
        Section(
            id: "restrictions",
            heading: "2. Restrictions",
            paragraphs: [
                "You agree not to copy, modify, translate, reverse engineer, decompile, or disassemble the App, or otherwise attempt to derive its source code, except to the extent this restriction is expressly prohibited by applicable law.",
                "You may not rent, lease, lend, sell, sublicense, or redistribute the App, and you may not remove or alter any copyright, trademark, or other proprietary notices. You agree not to use the App to violate any applicable law or regulation."
            ]
        ),
        Section(
            id: "account",
            heading: "3. Your Account and the MasjidPro / Al-Burooj Iqama Service",
            paragraphs: [
                "The App displays prayer, Iqama, and announcement information provided by a masjid through its MasjidPro / Al-Burooj Iqama account. You are responsible for keeping any device code or credentials associated with the App confidential and for all activity performed through them.",
                "Prayer and Iqama times are provided for convenience. Times may vary by calculation method and location, and you should verify them with your local masjid. The developer does not guarantee their accuracy."
            ]
        ),
        Section(
            id: "data",
            heading: "4. Privacy and Data",
            paragraphs: [
                "Your use of the App is subject to our Privacy Policy, which explains what information is collected, how it is used, and the choices you have. By using the App you consent to the practices described there."
            ]
        ),
        Section(
            id: "content",
            heading: "5. Content and Third Parties",
            paragraphs: [
                "The App may include audio content (such as Adhan recitations) and links to third-party websites or services. Such third-party materials remain the property of their respective owners and are subject to their own terms. The developer is not responsible for third-party content or services."
            ]
        ),
        Section(
            id: "termination",
            heading: "6. Updates and Termination",
            paragraphs: [
                "The developer may update, modify, or discontinue the App or any feature at any time. This license remains in effect until terminated. It terminates automatically if you breach any term of this Agreement. You may stop using the App at any time."
            ]
        ),
        Section(
            id: "disclaimer",
            heading: "7. Disclaimer of Warranties",
            paragraphs: [
                "TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE APP IS PROVIDED AS IS AND AS AVAILABLE, WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT."
            ]
        ),
        Section(
            id: "liability",
            heading: "8. Limitation of Liability",
            paragraphs: [
                "TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, X2Soft INC. SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR FOR ANY LOSS OF PROFITS, REVENUE, DATA, OR GOODWILL, ARISING OUT OF OR RELATED TO YOUR USE OR INABILITY TO USE THE APP. THE DEVELOPER'S TOTAL LIABILITY SHALL NOT EXCEED THE AMOUNT YOU PAID, IF ANY, FOR THE APP."
            ]
        ),
        Section(
            id: "changes",
            heading: "9. Changes to This Agreement",
            paragraphs: [
                "We may revise this Agreement from time to time. The most current version will always be shown here. If a revision is material, we will make reasonable efforts to notify you. By continuing to use the App after changes take effect, you accept the revised Agreement."
            ]
        ),
        Section(
            id: "governing",
            heading: "10. Governing Law",
            paragraphs: [
                "This Agreement is governed by the laws of [Jurisdiction], without regard to its conflict-of-law principles. Any dispute arising under this Agreement shall be subject to the exclusive jurisdiction of the courts located in [Jurisdiction]."
            ]
        ),
        Section(
            id: "contact",
            heading: "11. Contact",
            paragraphs: [
                "If you have any questions about this Agreement, please contact us at support@x2softinc.com."
            ]
        )
    ]

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("End User License Agreement")
                .font(.title2.weight(.bold))
            Text(LegalDocument.termsOfUse.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.heading)
                .font(.headline)
            ForEach(section.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var effectiveDateBlock: some View {
        Text("Last updated: [Date]")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    NavigationStack {
        EULAView()
    }
}
