//
//  DynamicIslandView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI

struct DynamicIslandView: View {
    @StateObject var vm: DynamicIslandViewModel

    @State var dropTargeting: Bool = false

    init(vm: DynamicIslandViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var notchSize: CGSize {
        switch vm.status {
        case .closed:
            var ans = CGSize(
                width: vm.deviceNotchRect.width - 4,
                height: vm.deviceNotchRect.height - 4
            )
            if ans.width < 0 { ans.width = 0 }
            if ans.height < 0 { ans.height = 0 }
            return ans
        case .opened:
            return vm.notchOpenedSize
        case .dropdown:
            return vm.notchDropdownSize
        case .popping:
            return .init(
                width: vm.deviceNotchRect.width + 120,
                height: vm.deviceNotchRect.height
            )
        }
    }

    var notchCornerRadius: CGFloat {
        switch vm.status {
        case .closed: 8
        case .opened: 32
        case .dropdown: 32
        case .popping: 10
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            notch
                .zIndex(0)
                .disabled(true)
                .opacity(vm.notchVisible ? 1 : 0.3)

            // Popping state: show countdown pill preview
            Group {
                if vm.status == .popping {
                    HStack(spacing: 0) {
                        Spacer()
                        CountdownPillView(
                            taskStore: vm.taskStore,
                            profile: vm.profile
                        )
                        .padding(.trailing, 8)
                    }
                    .frame(width: vm.deviceNotchRect.width + 120, height: vm.deviceNotchRect.height)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(1)
                }
            }

            // Opened state: full panel content
            Group {
                if vm.status == .opened {
                    VStack(spacing: vm.spacing) {
                        DynamicIslandHeaderView(vm: vm)
                        DynamicIslandContentView(vm: vm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(vm.spacing)
                    .frame(
                        maxWidth: vm.notchOpenedSize.width,
                        maxHeight: vm.notchOpenedSize.height
                    )
                    .zIndex(2)
                }
            }
            .transition(
                .scale.combined(
                    with: .opacity
                ).combined(
                    with: .offset(y: -vm.notchOpenedSize.height / 2)
                ).animation(vm.animation)
            )

            // Dropdown state: task list
            Group {
                if vm.status == .dropdown {
                    VStack(spacing: 0) {
                        // Mini header
                        HStack {
                            Text("CATS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Text(CatFaces.page.dropdown)
                                .font(.system(size: 11))
                            Spacer()
                            Text("\(vm.taskStore.activeTasks.count) active")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                        TaskListView(
                            taskStore: vm.taskStore,
                            profile: vm.profile,
                            vm: vm
                        )
                    }
                    .frame(
                        maxWidth: vm.notchDropdownSize.width,
                        maxHeight: vm.notchDropdownSize.height
                    )
                    .zIndex(2)
                }
            }
            .transition(
                .scale.combined(
                    with: .opacity
                ).combined(
                    with: .offset(y: -vm.notchDropdownSize.height / 2)
                ).animation(vm.animation)
            )
        }
        .animation(
            [.opened, .popping, .dropdown].contains(vm.status)
                ? vm.animation
                : .interactiveSpring(
                    duration: 0.5,
                    extraBounce: 0.01,
                    blendDuration: 0.125
                ),
            value: vm.status
        )
        .animation(vm.animation, value: vm.contentType)
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var notch: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(notchBackgroundMaskGroup)
            .frame(
                width: notchSize.width + notchCornerRadius * 2,
                height: notchSize.height
            )
            .shadow(
                color: shadowColor,
                radius: 16
            )
    }

    private var shadowColor: Color {
        if [.opened, .popping, .dropdown].contains(vm.status) {
            if let task = vm.taskStore.nextDeadlineTask, task.isUrgent {
                return .red.opacity(0.6)
            }
            return .black.opacity(1)
        }
        return .clear
    }

    var notchBackgroundMaskGroup: some View {
        Rectangle()
            .foregroundStyle(.black)
            .frame(
                width: notchSize.width,
                height: notchSize.height
            )
            .clipShape(.rect(
                bottomLeadingRadius: notchCornerRadius,
                bottomTrailingRadius: notchCornerRadius
            ))
            .overlay {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .frame(width: notchCornerRadius, height: notchCornerRadius)
                        .foregroundStyle(.black)
                    Rectangle()
                        .clipShape(.rect(topLeadingRadius: notchCornerRadius))
                        .foregroundStyle(.white)
                        .frame(
                            width: notchCornerRadius + vm.spacing,
                            height: notchCornerRadius + vm.spacing
                        )
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: notchCornerRadius + vm.spacing - 0.5, y: -0.5)
            }
            .overlay {
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .frame(width: notchCornerRadius, height: notchCornerRadius)
                        .foregroundStyle(.black)
                    Rectangle()
                        .clipShape(.rect(topTrailingRadius: notchCornerRadius))
                        .foregroundStyle(.white)
                        .frame(
                            width: notchCornerRadius + vm.spacing,
                            height: notchCornerRadius + vm.spacing
                        )
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -notchCornerRadius - vm.spacing + 0.5, y: -0.5)
            }
    }
}
