//
//  ViewController.swift
//  SpeedReader-iOS
//
//  Created by Blake Tsuzaki on 1/19/17.
//  Copyright © 2017 Modoki. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var gestureArea: UIView!
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet var panGestureRecognizer: UIPanGestureRecognizer!
    var spokenTextLengths: Int = 0
    var totalUtterances: Int = 0
    var currentUtterance: Int = 0
    var currentWord: Int = 0
    var previousSelectedRange: NSRange?
    var utteranceTexts: [String]?
    var previousTranslation = CGPoint(x: 0, y: 0)
    var nextWord: Int = 0
    
    override var prefersStatusBarHidden: Bool {
        get { return true }
    }
    let speechSynthesizer = AVSpeechSynthesizer()
    let alternateSpeechSynthesizer = AVSpeechSynthesizer()
    let wordScrollUnit: CGFloat = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gestureArea.layer.cornerRadius = 10
        tapGestureRecognizer.addTarget(self, action: #selector(ViewController.userDidTapGestureArea))
        panGestureRecognizer.addTarget(self, action: #selector(ViewController.userDidPanGestureArea))
        
        speechSynthesizer.delegate = self
    }
    
    func userDidTapGestureArea(sender:UITapGestureRecognizer) {
        if speechSynthesizer.isSpeaking {
            if (speechSynthesizer.isPaused) { speechSynthesizer.continueSpeaking() }
            else { speechSynthesizer.pauseSpeaking(at: AVSpeechBoundary.word) }
        } else {
            let utteranceTexts = textView.text.components(separatedBy: "\n")
            totalUtterances = utteranceTexts.count
            currentUtterance = 0
            currentWord = 0
            for utteranceText in utteranceTexts {
                let utterance = AVSpeechUtterance(string: utteranceText)
                
                speechSynthesizer.speak(utterance)
            }
            self.utteranceTexts = utteranceTexts
        }
    }
    
    func userDidPanGestureArea(sender:UIPanGestureRecognizer) {
        if (speechSynthesizer.isSpeaking) { speechSynthesizer.stopSpeaking(at: AVSpeechBoundary.immediate) }
        let translation = sender.translation(in: sender.view)
        let textRange = textView.text.components(separatedBy: " ")
        
        if (translation.x != previousTranslation.x) {
            if (floor(translation.x/wordScrollUnit) != floor(previousTranslation.x/wordScrollUnit)) {
                let indexOffset = floor(translation.x/wordScrollUnit)
                let wordOffset = currentWord + Int(indexOffset)
                
                if wordOffset >= 0 && wordOffset < textRange.count {
                    let utterance = AVSpeechUtterance(string: textRange[wordOffset])
                    utterance.rate = 0.6
                    utterance.preUtteranceDelay = 0.0
                    utterance.postUtteranceDelay = 0.0
                    AVSpeechSynthesizer().speak(utterance)
                    
                    var wordPosition = 0
                    if wordOffset > 0 {
                        for idx in 0...wordOffset-1 {
                            wordPosition += textRange[idx].characters.count
                        }
                    }
                    wordPosition += wordOffset
                    
                    let rangeInTotalText = NSRange(location: wordPosition, length: textRange[wordOffset].characters.count)
                    highlightRange(rangeInTotalText)
                    
                    print(textRange[wordOffset])
                    
                    nextWord = wordOffset
                }
            }
            previousTranslation = translation
        }
    }

    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }
    
    func unselectLastWord() {
        if let selectedRange = previousSelectedRange {
            let currentAttributes = textView.attributedText.attributes(at: selectedRange.location, effectiveRange: nil)
            let fontAttribute: AnyObject? = currentAttributes[NSFontAttributeName] as AnyObject?
            let attributedWord = NSMutableAttributedString(string: textView.attributedText.attributedSubstring(from: selectedRange).string)

            attributedWord.addAttribute(NSForegroundColorAttributeName, value: UIColor.black, range: NSMakeRange(0, attributedWord.length))
            attributedWord.addAttribute(NSFontAttributeName, value: fontAttribute!, range: NSMakeRange(0, attributedWord.length))
            
            textView.textStorage.beginEditing()
            textView.textStorage.replaceCharacters(in: selectedRange, with: attributedWord)
            textView.textStorage.endEditing()
        }
    }
    
    func highlightRange(_ rangeInTotalText: NSRange) {
        let currentAttributes = textView.attributedText.attributes(at: rangeInTotalText.location, effectiveRange: nil)
        let fontAttribute: AnyObject? = currentAttributes[NSFontAttributeName] as AnyObject?
        let attributedString = NSMutableAttributedString(string: textView.attributedText.attributedSubstring(from: rangeInTotalText).string)
        
        attributedString.addAttribute(NSForegroundColorAttributeName, value: UIColor.orange, range: NSMakeRange(0, attributedString.length))
        
        attributedString.addAttribute(NSFontAttributeName, value: fontAttribute!, range: NSMakeRange(0, attributedString.string.utf16.count))
        
        textView.scrollRangeToVisible(rangeInTotalText)
        textView.textStorage.beginEditing()
        textView.textStorage.replaceCharacters(in: rangeInTotalText, with: attributedString)
        
        if let previousRange = previousSelectedRange {
            let previousAttributedText = NSMutableAttributedString(string: textView.attributedText.attributedSubstring(from: previousRange).string)
            previousAttributedText.addAttribute(NSForegroundColorAttributeName, value: UIColor.black, range: NSMakeRange(0, previousAttributedText.length))
            previousAttributedText.addAttribute(NSFontAttributeName, value: fontAttribute!, range: NSMakeRange(0, previousAttributedText.length))
            
            textView.textStorage.replaceCharacters(in: previousRange, with: previousAttributedText)
        }
        
        textView.textStorage.endEditing()
        previousSelectedRange = rangeInTotalText
    }
}

extension ViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        spokenTextLengths = spokenTextLengths + utterance.speechString.utf16.count + 1
        
        if currentUtterance == totalUtterances {
            unselectLastWord()
            previousSelectedRange = nil
        }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let rangeInTotalText = NSMakeRange(spokenTextLengths + characterRange.location, characterRange.length)
        
        currentWord += 1
        textView.selectedRange = rangeInTotalText
        lastRange = characterRange
        
        highlightRange(rangeInTotalText)
    }
}
