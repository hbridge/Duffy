//
//  DFProfilePhotoView.swift
//  Strand
//
//  Created by Henry Bridge on 9/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

import UIKit

class DFProfilePhotoView: UIView {

  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var textLabel: UILabel!
  
  override func layoutSubviews() {
    super.layoutSubviews()
    self.layer.cornerRadius = self.frame.size.width/2
  }
  
  func setProfileImage(image: UIImage){
    self.imageView.image = image
    self.textLabel.hidden = true
  }
  
  func setNameAbbreviation(abbreviation: NSString) {
    self.textLabel.text = abbreviation
  }
  
}
