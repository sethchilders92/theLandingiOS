//
//  SecondViewController.swift
//  theLanding
//
//  Created by Seth Childers on 2/4/19.
//  Copyright © 2019 Seth Childers. All rights reserved.
//

import UIKit

class SecondViewController: UIViewController {
    
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var backBtnConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewConstraint: NSLayoutConstraint!
    
    //width of the screen -- will be set in btnClick functions
    var width: CGFloat = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backBtn.layer.cornerRadius = 4
    }

    @IBAction func backBtnClick(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
}

