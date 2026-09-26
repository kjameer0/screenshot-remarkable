// Lists on-screen windows as: <windowID>\t<width>x<height>\t<ownerName>\t<windowTitle>
//   winid                          -> list all capturable windows, largest first
//   winid <owner> [titleSubstring] -> print just that window's ID
// Owner-name matches outrank title-only matches, so an unrelated browser tab
// merely mentioning the app name can't win. Needs Screen Recording permission.
import CoreGraphics
import Foundation

let args = CommandLine.arguments
let needle = args.count > 1 ? args[1].lowercased() : nil
let titleNeedle = args.count > 2 ? args[2].lowercased() : nil

guard let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
) as? [[String: Any]] else {
    FileHandle.standardError.write("cannot read window list\n".data(using: .utf8)!)
    exit(2)
}

struct Win { let id: Int; let w: Int; let h: Int; let owner: String; let title: String }

let list: [Win] = windows.compactMap { win in
    guard let id = win[kCGWindowNumber as String] as? Int,
          let bounds = win[kCGWindowBounds as String] as? [String: Any],
          let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double
    else { return nil }
    let owner = win[kCGWindowOwnerName as String] as? String ?? ""
    let title = win[kCGWindowName as String] as? String ?? ""
    // Skip menubar-sized slivers and other chrome.
    guard w > 120, h > 120 else { return nil }
    return Win(id: id, w: Int(w), h: Int(h), owner: owner, title: title)
}

if let needle {
    var matches = list.filter {
        $0.owner.lowercased().contains(needle) || $0.title.lowercased().contains(needle)
    }
    if let titleNeedle {
        let titled = matches.filter { $0.title.lowercased().contains(titleNeedle) }
        if !titled.isEmpty { matches = titled }
    }
    // Rank: owner-name match first, then larger area (the canvas, not a palette).
    let best = matches.max { a, b in
        let ao = a.owner.lowercased().contains(needle), bo = b.owner.lowercased().contains(needle)
        if ao != bo { return bo }
        return a.w * a.h < b.w * b.h
    }
    guard let best else { exit(1) }
    print(best.id)
} else {
    for win in list.sorted(by: { $0.w * $0.h > $1.w * $1.h }) {
        print("\(win.id)\t\(win.w)x\(win.h)\t\(win.owner)\t\(win.title)")
    }
}
