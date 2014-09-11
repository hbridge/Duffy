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
    self.imageView.backgroundColor = UIColor(white: 0.5, alpha: 1.0);
    //self.layer.cornerRadius = self.frame.size.width/2
  }
  
  override func awakeFromNib() {
    //self.layer.cornerRadius = self.frame.size.width/2
    self.layer.masksToBounds = true
  }
  
  func setProfileImage(image: UIImage){
    self.imageView.image = image
    self.textLabel.hidden = true
  }
  
  func setNameAbbreviation(abbreviation: NSString) {
    self.textLabel.text = abbreviation
  }
  
}
