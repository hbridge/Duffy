//
//  DFSelectPhotosHeaderView.swift
//  Strand
//
//  Created by Henry Bridge on 9/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

import UIKit

class DFSelectPhotosHeaderView: UICollectionReusableView {
  @IBOutlet weak var textLabel: UILabel!
  @IBOutlet weak var actorsLabel: UILabel!
  
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
  
  class func HeaderHeight() -> CGFloat {
    return 49.0
  }
    
}
