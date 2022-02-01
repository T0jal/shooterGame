//
//  GameScene.swift
//  ShooterGame
//
//  Created by António Rocha on 03/01/2022.
//

import SpriteKit

var scoreLabel: SKLabelNode!
var clockLabel: SKLabelNode!

var gameTimer: Timer?
var timerInterval = 1.0

var timeLeft = 60 {
    didSet {
        clockLabel.text = "Time left: \(timeLeft)"
    }
}

var score = 0 {
    didSet {
        scoreLabel.text = "Score: \(score)"
    }
}

let enemies = ["target0", "target1", "target2", "target3"]
let rows = ["top", "middle", "bottom"]

let goSlow = 300
let goFast = 600

var targetsTimer: Timer?
var targetCreationInterval = 0.4

var bulletsLeft = 6
let bullets = ["shots0", "shots1", "shots2", "shots3"]
var reloadLocation = CGRect()

var gameOver = false

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    override func didMove(to view: SKView) {
       
        let viewSize = view.frame.size
        createScenario(with: viewSize)
        
        reloadLocation = CGRect(x: 0, y: 0, width: viewSize.width, height: 145.0)
        
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        gameTimer = Timer.scheduledTimer(timeInterval: timerInterval, target: self, selector: #selector(updateClock), userInfo: nil, repeats: true)
        
        targetsTimer = Timer.scheduledTimer(timeInterval: targetCreationInterval, target: self, selector: #selector(createTarget), userInfo: nil, repeats: true)
    }
    
    func createScenario(with viewSize: CGSize) {
        let background = SKSpriteNode(imageNamed: "wood-background")
        background.position = CGPoint(x: 512, y: 384)
        background.size = viewSize
        background.blendMode = .replace
        addChild(background)
        
        let curtains = SKSpriteNode(imageNamed: "curtains")
        curtains.position = CGPoint(x: 512, y: 384)
        curtains.size = viewSize
        curtains.zPosition = 1
        addChild(curtains)
        
        scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
        scoreLabel.position = CGPoint(x: 900, y: 40)
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.zPosition = 500
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
        
        clockLabel = SKLabelNode(fontNamed: "Chalkduster")
        clockLabel.position = CGPoint(x: 900, y: 100)
        clockLabel.horizontalAlignmentMode = .right
        clockLabel.zPosition = 500
        clockLabel.text = "Time left: 60"
        addChild(clockLabel)
        
        fullClip()
    }
    
    @objc func createTarget() {
        guard let enemy = enemies.randomElement() else { return }
        guard let row = rows.randomElement() else { return }
        
        var position = CGPoint()
        var direction = CGVector(dx: goSlow, dy: 0)
        var xScale = 1.0
        var sizeScale = 1.0
        
        switch(row) {
        case "top":
            position = CGPoint(x: -200, y: 570)
        case "middle":
            position = CGPoint(x: 1200, y: 400)
            direction = CGVector(dx: -goFast, dy: 0)
            xScale = -1.0
            sizeScale = 0.75
        default:
            position = CGPoint(x: -200, y: 220)
        }
        
        let sprite = SKSpriteNode(imageNamed: enemy)
        sprite.position = position
        sprite.setScale(sizeScale)
        sprite.xScale = xScale
        sprite.name = enemy == "target0" ? "badTarget" : "goodTarget"
        addChild(sprite)

        sprite.physicsBody = SKPhysicsBody(texture: sprite.texture!, size: sprite.size)
        sprite.physicsBody?.categoryBitMask = 1
        sprite.physicsBody?.velocity = direction
        sprite.physicsBody?.linearDamping = 0
        sprite.physicsBody?.angularDamping = 0
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if gameOver { return }
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if reloadLocation.contains(location) {
            fullClip()
            run(SKAction.playSoundFileNamed("reload.wav", waitForCompletion: false))
            return
        }
        
        if bulletsLeft == 0 {
            run(SKAction.playSoundFileNamed("empty.wav", waitForCompletion: false))
            return
        }
        
        run(SKAction.playSoundFileNamed("shot.wav", waitForCompletion: false))
        updateClips()
        
        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            if node.name == "goodTarget" || node.name == "badTarget" {
                burn(this: node)
                node.removeFromParent()
                updateScore(withThis: node)
            }
        }
    }
    
    func fullClip() {
        bulletsLeft = 6
        showBulletClips(with: bullets[3], and: bullets[3])
    }
    
    func updateClips() {
        bulletsLeft -= 1
        switch(bulletsLeft) {
            case 5: showBulletClips(with: bullets[2], and: bullets[3])
            case 4: showBulletClips(with: bullets[1], and: bullets[3])
            case 3: showBulletClips(with: bullets[0], and: bullets[3])
            case 2: showBulletClips(with: bullets[0], and: bullets[2])
            case 1: showBulletClips(with: bullets[0], and: bullets[1])
            default: showBulletClips(with: bullets[0], and: bullets[0])
        }
    }
    
    func showBulletClips(with topRow: String, and bottomRow: String) {
        for node in children {
            if node.name == "topRow" || node.name == "bottomRow" {
                node.removeFromParent()
            }
        }
        let topRowOfBullets = SKSpriteNode(imageNamed: topRow)
        topRowOfBullets.position = CGPoint(x: 160, y: 100)
        topRowOfBullets.zPosition = 500
        topRowOfBullets.name = "topRow"
        addChild(topRowOfBullets)
        
        let bottomRowOfBullets = SKSpriteNode(imageNamed: bottomRow)
        bottomRowOfBullets.position = CGPoint(x: 160, y: 50)
        bottomRowOfBullets.zPosition = 500
        bottomRowOfBullets.name = "bottomRow"
        addChild(bottomRowOfBullets)
    }
    
    func burn(this node: SKNode) {
        if let fire = SKEmitterNode(fileNamed: "fire.sks") {
            fire.position = node.position
                fire.numParticlesToEmit = 500
                addChild(fire)
        }
    }
    
    func updateScore(withThis node: SKNode) {
        if node.name == "goodTarget" {
            //targets in the middle row are worth more as they are smaller and faster
            let yPosition = node.position.y
            if yPosition > 399 && yPosition < 401 {
                score += 3
            } else {
                score += 1
            }
            
        } else if node.name == "badTarget" {
            score -= 5
        }
    }
    
    @objc func updateClock() {
        timeLeft -= 1
        if timeLeft == 0 {
            gameTimer?.invalidate()
            targetsTimer?.invalidate()
            endGame()
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        for node in children {
            if node.position.x < -300 || node.position.x > 1324 {
                node.removeFromParent()
            }
        }
    }
    
    func endGame() {
        gameOver = true
        
        let gameOver = SKSpriteNode(imageNamed: "game-over")
        gameOver.position = CGPoint(x: 512, y: 384)
        gameOver.zPosition = 1
        addChild(gameOver)
        
        let endScore = SKLabelNode()
        endScore.text = "Final Score: \(score)"
        endScore.position = CGPoint(x: 512, y: 250)
        endScore.zPosition = 1
        endScore.fontSize = 60
        endScore.alpha = 1
        endScore.fontName = "AvenirNext-Bold"
        addChild(endScore)
        
        run(SKAction.playSoundFileNamed("gameOver.mp3", waitForCompletion: false))
    }
}
