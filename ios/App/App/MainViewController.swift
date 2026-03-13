import UIKit
import Capacitor

class MainViewController: CAPBridgeViewController {
    override func instanceDescriptor() -> InstanceDescriptor {
        let descriptor = super.instanceDescriptor()
        descriptor.serverURL = URL(string: "https://spotd.biz")
        return descriptor
    }
}
