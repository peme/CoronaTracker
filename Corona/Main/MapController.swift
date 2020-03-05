//
//  ViewController.swift
//  Corona
//
//  Created by Mohammad on 3/2/20.
//  Copyright © 2020 Samabox. All rights reserved.
//

import UIKit
import MapKit

import CodableCSV
import FloatingPanel
import PKHUD

class MapController: UIViewController {
	private let maxDataAge = 6 // Hours

	static var instance: MapController!

	private var allAnnotations: [VirusReportAnnotation] = []
	private var mainAnnotations: [VirusReportAnnotation] = []
	private var annotations: [VirusReportAnnotation] = []

	private var panelController: FloatingPanelController!
	private var regionContainerController: RegionContainerController!

	@IBOutlet var mapView: MKMapView!
	@IBOutlet var effectView: UIVisualEffectView!

	override func viewDidLoad() {
		super.viewDidLoad()

		MapController.instance = self

		if #available(iOS 13.0, *) {
			effectView.effect = UIBlurEffect(style: .systemThinMaterial)
		}

		let identifier = String(describing: RegionContainerController.self)
		regionContainerController = storyboard?.instantiateViewController(
			withIdentifier: identifier) as? RegionContainerController

		panelController = FloatingPanelController()
		panelController.delegate = self
		panelController.surfaceView.cornerRadius = 12
		panelController.surfaceView.shadowHidden = false
		panelController.set(contentViewController: regionContainerController)
		panelController.track(scrollView: regionContainerController.regionController.tableView)
		panelController.surfaceView.backgroundColor = .clear
		panelController.surfaceView.contentView.backgroundColor = .clear

		mapView.register(VirusReportAnnotationView.self,
						 forAnnotationViewWithReuseIdentifier: VirusReportAnnotation.reuseIdentifier)
		mapView.showsPointsOfInterest = false

		update()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		panelController.addPanel(toParent: self, animated: true)
		regionContainerController.regionController.tableView.setContentOffset(.zero, animated: false)

		downloadIfNeeded()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		panelController.removePanelFromParent(animated: animated)
	}

	func updateRegionScreen(report: VirusReport?) {
		regionContainerController.regionController.virusReport = report
		regionContainerController.regionController.update()
	}

	func showRegionScreen() {
		panelController.move(to: .full, animated: true)
	}

	func hideRegionScreen() {
		panelController.move(to: .half, animated: true)
	}

	private func update() {
		guard VirusDataManager.instance.load() else { return }

		for report in VirusDataManager.instance.allReports where report.data.confirmedCount > 0 {
			let annotation = VirusReportAnnotation(virusReport: report)
			allAnnotations.append(annotation)
		}

		for report in VirusDataManager.instance.mainReports where report.data.confirmedCount > 0 {
			let annotation = VirusReportAnnotation(virusReport: report)
			mainAnnotations.append(annotation)
		}

		annotations = allAnnotations
		mapView.addAnnotations(annotations)

		regionContainerController.regionController.update()
	}

	private func downloadIfNeeded() {
		if let age = VirusDataManager.instance.globalReport?.hourAge, age < maxDataAge {
			return
		}

		let showSpinner = allAnnotations.isEmpty
		if showSpinner {
			HUD.show(.label("Updating..."))
		}

		VirusDataManager.instance.download { success in
			if success {
				HUD.hide()
				if VirusDataManager.instance.load() {
					self.update()
				} else {
					if showSpinner {
						HUD.flash(.error, delay: 1.0)
					}
				}
			}
			else {
				if showSpinner {
					HUD.flash(.error, delay: 1.0)
				}
			}
		}
	}
}

extension MapController: MKMapViewDelegate {
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		guard !(annotation is MKUserLocation) else {
			return nil
		}

		guard let annotationView = mapView.dequeueReusableAnnotationView(
			withIdentifier: VirusReportAnnotation.reuseIdentifier,
			for: annotation) as? VirusReportAnnotationView else { return nil }

		annotationView.mapZoomLevel = mapView.zoomLevel

		return annotationView
	}

	func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
//		print(mapView.zoomLevel)
		for annotation in annotations {
			if let view = mapView.view(for: annotation) as? VirusReportAnnotationView {
				view.mapZoomLevel = mapView.zoomLevel
			}
		}

	}

	func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		if mapView.zoomLevel > 4 {
			if annotations.count != allAnnotations.count {
				mapView.removeAnnotations(annotations)
				annotations = allAnnotations
				mapView.addAnnotations(annotations)
			}
		}
		else {
			if annotations.count != mainAnnotations.count {
				mapView.removeAnnotations(annotations)
				annotations = mainAnnotations
				mapView.addAnnotations(annotations)
			}
		}
	}

	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		updateRegionScreen(report: (view as? VirusReportAnnotationView)?.virusReport)
	}

	func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
		updateRegionScreen(report: nil)
	}
}

extension MapController: FloatingPanelControllerDelegate {
	func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
		(newCollection.userInterfaceIdiom == .pad ||
			newCollection.verticalSizeClass == .compact) ? LandscapePanelLayout() : PanelLayout()
	}
}

class PanelLayout: FloatingPanelLayout {
	public var initialPosition: FloatingPanelPosition {
		return .half
	}

	public func insetFor(position: FloatingPanelPosition) -> CGFloat? {
		switch position {
		case .full: return 16
		case .half: return 180
		case .tip: return 64
		default: return nil
		}
	}

	func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
		return [
			surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 0.0),
			surfaceView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0.0),
		]
	}
}

class LandscapePanelLayout: PanelLayout {
	override func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
		return [
			surfaceView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8.0),
			surfaceView.widthAnchor.constraint(equalToConstant: 400),
		]
	}
}