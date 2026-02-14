//
//  DynamicIslandViewController.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import Cocoa
import SwiftUI

class DynamicIslandViewController: NSHostingController<DynamicIslandView> {
    init(_ vm: DynamicIslandViewModel) {
        super.init(rootView: DynamicIslandView(vm: vm))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
    }
}
