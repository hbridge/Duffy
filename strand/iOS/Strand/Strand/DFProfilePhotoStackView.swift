//
//  DFProfilePhotoStackView.swift
//  Strand
//
//  Created by Henry Bridge on 9/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

import UIKit

class DFProfilePhotoStackView: UIView {
  let MaxProfilePhotos = 4;
  let profilePhotoWidth:CGFloat = 35.0;
  var expandedNameLabel: UILabel = UILabel()
  
  var names: [String] = [] {
    didSet {
      self.setProfilePhotoViews()
    }
  }
  
  override func awakeFromNib() {
    var tapRecognizer = UITapGestureRecognizer(target: self, action: Selector("tapped:"))
    tapRecognizer.numberOfTapsRequired = 1
    self.addGestureRecognizer(tapRecognizer)
  }

  func setProfilePhotoViews() {
    self.sizeToFit()
    self.setNeedsDisplay()
    self.superview?.setNeedsLayout()
  }
  
  override func sizeThatFits(size: CGSize) -> CGSize {
    var newSize = size;
    newSize.height = profilePhotoWidth
    newSize.width = CGFloat(min(MaxProfilePhotos + 1, self.names.count)) * profilePhotoWidth
    return newSize
  }
  
  func rectForIndex(index: Int) -> CGRect {
    var rect =
    CGRectMake(
      CGFloat(index) * self.profilePhotoWidth,
      0,
      profilePhotoWidth,
      profilePhotoWidth)
    if index > 0 {
      rect.origin.x += 2
    }

    return rect
  }
  
  override func drawRect(rect: CGRect) {
    var context = UIGraphicsGetCurrentContext()
    // no CGColorRelease needed, swift handles memory management
    var fillColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), [0.5, 0.5, 0.5, 1.0])
    
    for (i, name) in enumerate(names) {
      var abbreviation = name.substringToIndex(name.startIndex.successor()).capitalizedString
      var abbreviationRect = self.rectForIndex(i)
      CGContextSetFillColorWithColor(context, fillColor)
      CGContextFillEllipseInRect(context, abbreviationRect)
      
      var label = UILabel(frame: abbreviationRect)
      label.textColor = UIColor(white: 1.0, alpha: 1.0)
      label.textAlignment = .Center
      label.text = abbreviation
      label.font = UIFont(name:"HelveticaNeue", size: abbreviationRect.size.height/2)
      label.drawTextInRect(abbreviationRect)
    }
  }
  
  func tapped(sender: UITapGestureRecognizer) {
    // figure out which name was tapped
    for i in 0...self.names.count {
      var rect = self.rectForIndex(i)
      var tapPoint = sender.locationInView(self)
      if CGRectContainsPoint(rect, tapPoint) {
        self.iconTappedForIndex(i, rect: rect)
      }
    }
  }
  
  let labelHeight: CGFloat = 20.0
  func iconTappedForIndex(i: Int, rect: CGRect) {
    if i > self.names.count {return}
    var name = self.names[i]
    
    var labelRect = CGRectMake(
      rect.maxX,
      rect.midY - labelHeight/2.0,
      rect.size.width * 2.0,
      labelHeight)
    var rectInSuper = self.superview?.convertRect(labelRect, fromView: self)
    
    expandedNameLabel.removeFromSuperview()
    expandedNameLabel = UILabel(frame: rectInSuper!)
    expandedNameLabel.font = UIFont.systemFontOfSize(15.0)
    expandedNameLabel.adjustsFontSizeToFitWidth = true
    expandedNameLabel.minimumScaleFactor = 0.1
    expandedNameLabel.text = name
    expandedNameLabel.backgroundColor = UIColor.blackColor()
    expandedNameLabel.textColor = UIColor.whiteColor()
    expandedNameLabel.layer.cornerRadius = 5.0
    expandedNameLabel.layer.masksToBounds = true
    expandedNameLabel.textAlignment = .Center

    self.superview?.addSubview(expandedNameLabel)
    
    UIView.animateKeyframesWithDuration(1.0, delay: 1.0, options: UIViewKeyframeAnimationOptions(), animations: { () -> Void in
      self.expandedNameLabel.alpha = 0.0
    }) { (done) -> Void in
      self.expandedNameLabel.removeFromSuperview()
    }
  }
  
  
}
