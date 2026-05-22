import Testing
import Foundation
@testable import VoxlueServices

@Test func shareInvitationCarriesURL() {
    let url = URL(string: "https://www.icloud.com/share/0ABC")!
    let invitation = ShareInvitation(url: url)
    #expect(invitation.url == url)
}
