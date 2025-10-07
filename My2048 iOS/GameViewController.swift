//
//  GameViewController.swift
//  My2048 iOS
//
//  Created by Jiayi on 10/7/25.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private let store = GameStore()
    private var gameScene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView = self.view as! SKView
        let scene = GameScene.makeScene(size: skView.bounds.size, store: store)
        gameScene = scene
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
