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
  
  var abbreviations: [String] = [] {
    didSet {
      self.setProfilePhotoViews()
    }
  }

  func setProfilePhotoViews() {
    self.sizeToFit()
    self.setNeedsDisplay()
  }
  
  override func sizeThatFits(size: CGSize) -> CGSize {
    var newSize = size;
    newSize.height = profilePhotoWidth
    newSize.width = CGFloat(min(MaxProfilePhotos + 1, self.abbreviations.count)) * profilePhotoWidth
    return newSize
  }
  
  
  override func drawRect(rect: CGRect) {
    var context = UIGraphicsGetCurrentContext()
    
    for (i, abbreviation) in enumerate(abbreviations) {
      CGContextSetFillColor(context, [0.5, 0.5, 0.5, 1.0])
      var abbreviationRect =
        CGRectMake(
          CGFloat(i) * (self.frame.size.width - profilePhotoWidth)/CGFloat(abbreviations.count),
          0,
          profilePhotoWidth,
          profilePhotoWidth)
      CGContextFillEllipseInRect(context, abbreviationRect)
      
      var label = UILabel(frame: abbreviationRect)
      label.textColor = UIColor(white: 1.0, alpha: 1.0)
      label.textAlignment = .Center
      label.text = abbreviation
      label.drawTextInRect(abbreviationRect)
    }
    
  }
  
  
}
