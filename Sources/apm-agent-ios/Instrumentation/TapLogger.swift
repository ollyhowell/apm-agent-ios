// Copyright © 2021 Elasticsearch BV
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

#if os(iOS)
    import Accessibility
    import Foundation
    import OpenTelemetryApi
    import OpenTelemetrySdk
    import os
    import SwiftUI
    import UIKit

    class TouchLogger {
        private static var objectKey: UInt8 = 0
        static func printAccessibility(view: UIView) {
            print("Traits: \(view.accessibilityTraits)")
            print("Elements : \(String(describing: view.accessibilityElements))")
            print("Value : \(String(describing: view.accessibilityValue))")
            print("Hint : \(String(describing: view.accessibilityHint))")
            print("AttributedLabel : \(String(describing: view.accessibilityAttributedLabel))")
            print("Path : \(String(describing: view.accessibilityPath))")
            print("ContainerType : \(view.accessibilityContainerType)")
            if #available(iOS 13, *) {
                print("UserInputLabels : \(String(describing: view.accessibilityAttributedUserInputLabels))")
            }
        }

        static func startTrace(tracer: TracerSdk, event: UIEvent, config: UIApplicationInstrumentationConfiguration) -> Span? {
            if config.shouldInstrumentEvent(type: event.type) {
                for touch in event.allTouches ?? [] {
                    if touch.phase == .ended {
                        if let parentVc = TouchLogger.findViewController(ofView: touch.view), let view = touch.view {
                            if config.shouldFilter(cls: type(of: view)) {
                                return nil
                            }

                            var spanName = "tapped \(type(of: view))"

                            if config.useAccessibility, let accessibilityView = Self.findAccessibility(ofView: view) {
                                if let label = accessibilityView.accessibilityLabel {
                                    spanName += " \"\(label)\" "
                                }
                            }

                            spanName += " in \(type(of: parentVc))"
                            os_log("%@", spanName)

                            if let customName = config.customName?(touch, spanName) {
                                spanName = customName
                            }

                            let span = tracer.spanBuilder(spanName: spanName).setSpanKind(spanKind: .client).startSpan()
                            span.setAttribute(key: "touch.targetView", value: AttributeValue.string("\(type(of: view))"))
                            span.setAttribute(key: "touch.viewController", value: AttributeValue.string("\(type(of: parentVc))"))
                            span.setAttribute(key: "touch.type", value: AttributeValue.string(String(describing: touch.type)))
                            span.setAttribute(key: "event.type", value: AttributeValue.string(String(describing: event.type)))
                            span.setAttribute(key: "session.id", value: SessionManager.instance.session())
                            OpenTelemetrySDK.instance.contextProvider.setActiveSpan(span)
                            return span
                        }
                    }
                }
            }

            return nil
        }

        static func findAccessibility(ofView view: UIView?) -> UIView? {
            if let isView = view {
                if isView.isAccessibilityElement {
                    return isView
                } else {
                    return Self.findAccessibility(ofView: isView.superview)
                }
            }
            return nil
        }

        static func findViewController(ofView: UIView?) -> UIViewController? {
            guard let view = ofView else {
                return nil
            }
            if let nextResponder = view.next as? UIViewController {
                return nextResponder
            } else if let nextResponder = view.next as? UIView {
                return TouchLogger.findViewController(ofView: nextResponder)
            } else {
                return nil
            }
        }
    }
#endif // os(iOS)
