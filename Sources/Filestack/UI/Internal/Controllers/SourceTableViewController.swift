//
//  SourceTableViewController.swift
//  Filestack
//
//  Created by Ruben Nine on 11/7/17.
//  Copyright © 2017 Filestack. All rights reserved.
//

import FilestackSDK
import UIKit

class SourceTableViewController: UITableViewController {
    private let defaultSectionHeaderHeight: CGFloat = 32

    private var localSources = [LocalSource]()
    private var cloudSources = [CloudSource]()

    private var client: Client!
    private var storeOptions: StorageOptions!
    private var customSourceName: String?
    private var useCustomSource: Bool = false

    private var viewModel = Stylizer.SourceTableViewModel() {
        didSet {
            tableView.backgroundColor = viewModel.tableBackground
            tableView.separatorColor = viewModel.separatorColor
            title = viewModel.title
        }
    }

    private var uploader: (Cancellable & Monitorizable)?
    private var uploaderObserver: NSKeyValueObservation?

    private var uploadMonitorViewController: MonitorViewController?

    override public func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = cancelBarButton

        // Try to obtain `Client` object from navigation controller
        if let picker = navigationController as? PickerNavigationController {
            inject(client: picker.client, storageOptions: picker.storeOptions, viewModel: picker.stylizer.sourceTable)
        }
    }

    @IBAction func cancel(_: AnyObject?) {
        guard view.isUserInteractionEnabled else { return }
        dismiss(animated: true)
    }
}

// MARK: UITableViewDataSource

extension SourceTableViewController {
    override func numberOfSections(in _: UITableView) -> Int {
        return 2
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return localSources.count
        case 1: return cloudSources.count
        default: return 0
        }
    }

    override func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0: return !localSources.isEmpty ? defaultSectionHeaderHeight : 0
        case 1: return !cloudSources.isEmpty ? defaultSectionHeaderHeight : 0
        default: return 0
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return LocalSource.title()
        case 1: return CloudSource.title()
        default: return nil
        }
    }

    override func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = viewModel.headerTextFont
        header.textLabel?.textColor = viewModel.headerTextColor
        header.backgroundView?.backgroundColor = viewModel.headerBackgroundColor
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sourceTVC", for: indexPath)
        guard let source = source(from: indexPath) else { return cell }
        if source == CloudSource.customSource, useCustomSource {
            cell.textLabel?.text = customSourceName ?? source.textDescription
        } else {
            cell.textLabel?.text = source.textDescription
        }
        cell.accessoryType = .disclosureIndicator
        cell.imageView?.image = source.iconImage
        cell.imageView?.tintColor = viewModel.tintColor
        cell.textLabel?.textColor = viewModel.cellTextColor
        cell.textLabel?.font = viewModel.cellTextFont
        cell.backgroundColor = viewModel.cellBackgroundColor
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let source = source(from: indexPath) else { return }
        if let localSource = source as? LocalSource {
            sourceWasSelected(localSource)
        } else if let cloudSource = source as? CloudSource {
            sourceWasSelected(cloudSource)
        }
    }

    func sourceWasSelected(_ localSource: LocalSource) {
        switch localSource.provider {
        case .camera: upload(sourceType: .camera)
        case .photoLibrary: upload(sourceType: .photoLibrary)
        case .documents: upload()
        }
    }

    func sourceWasSelected(_ cloudSource: CloudSource) {
        // Try to retrieve store view type from user defaults, or default to "list"
        let viewType = UserDefaults.standard.cloudSourceViewType() ?? .list
        // Navigate to given cloud's "/" path
        let scene = CloudSourceTabBarScene(client: client,
                                           storeOptions: storeOptions,
                                           source: cloudSource,
                                           customSourceName: customSourceName,
                                           path: nil,
                                           nextPageToken: nil,
                                           viewType: viewType)

        if let vc = storyboard?.instantiateViewController(for: scene) {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    override func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 1
    }

    override func tableView(_: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return section == 0 ? nil : UIView()
    }
}

private extension SourceTableViewController {
    func inject(client: Client, storageOptions: StorageOptions, viewModel: Stylizer.SourceTableViewModel) {
        // Keep a reference to the `Client` object so we can use it later.
        self.client = client
        // Keep a reference to the `StoreOptions` object so we can use it later.
        storeOptions = storageOptions

        self.viewModel = viewModel

        // Get available local sources from config
        localSources = client.config.availableLocalSources

        // Get available cloud sources from config, but discard "custom source" (if present)
        // We will add it later, only if it is actually enabled in the Developer Portal.
        cloudSources = client.config.availableCloudSources.filter { $0.provider != .customSource }

        fetchCustomSourceSettingsIfNeeded()
    }

    func fetchCustomSourceSettingsIfNeeded() {
        if wantToPresentCustomSource {
            fetchCustomSourceSettings()
        }
    }

    func fetchCustomSourceSettings() {
        // Fetch configuration info from the API — don't care if it fails.
        client.prefetch { response in
            guard let contents = response.contents else { return }
            self.useCustomSource = contents["customsource"] as? Bool ?? false
            self.customSourceName = contents["customsource_name"] as? String
            if self.useCustomSource, self.wantToPresentCustomSource {
                self.cloudSources = self.client.config.availableCloudSources
            }
            self.tableView.reloadSections([1], with: .automatic)
        }
    }

    var wantToPresentCustomSource: Bool {
        return client.config.availableCloudSources.contains(where: { $0.provider == .customSource })
    }

    var cancelBarButton: UIBarButtonItem {
        return UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel))
    }

    func upload(sourceType: UIImagePickerController.SourceType? = nil) {
        guard let picker = navigationController as? PickerNavigationController else { return }

        let completionHandler: (([JSONResponse]) -> Void) = { responses in
            self.uploaderObserver = nil
            self.uploader = nil

            // Dismiss upload monitor
            self.uploadMonitorViewController?.dismiss(animated: true) {
                self.uploadMonitorViewController = nil

                if let error = responses.isEmpty ? Error.cancelled : responses.compactMap(\.error).first {
                    let alert = UIAlertController(title: "Upload Failed",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)

                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                        picker.pickerDelegate?.pickerUploadedFiles(picker: picker, responses: responses)
                    }))

                    picker.present(alert, animated: true)
                } else {
                    picker.pickerDelegate?.pickerUploadedFiles(picker: picker, responses: responses)
                }
            }
        }

        let uploadOptions = UploadOptions.defaults

        uploadOptions.storeOptions = storeOptions

        let uploader: Cancellable & Monitorizable

        if let sourceType = sourceType {
            uploader = client.uploadFromImagePicker(viewController: self,
                                                    sourceType: sourceType,
                                                    options: uploadOptions,
                                                    completionHandler: completionHandler)
        } else {
            uploader = client.uploadFromDocumentPicker(viewController: self,
                                                       options: uploadOptions,
                                                       completionHandler: completionHandler)
        }

        self.uploader = uploader

        // As soon as we detect some activity, we will present the upload monitor.
        uploaderObserver = uploader.progress.observe(\.totalUnitCount, options: [.new]) { progress, change in
            // Remove observer, we no longer need to observe changes.
            self.uploaderObserver = nil

            DispatchQueue.main.async {
                // Present upload monitor.
                let monitorViewController = MonitorViewController(progressable: uploader)
                monitorViewController.modalPresentationStyle = .currentContext

                self.uploadMonitorViewController = monitorViewController

                self.present(monitorViewController, animated: true, completion: nil)
            }
        }
    }

    func source(from indexPath: IndexPath) -> CellDescriptibleSource? {
        switch indexPath.section {
        case 0: return localSources[indexPath.row]
        case 1: return cloudSources[indexPath.row]
        default: return nil
        }
    }
}
