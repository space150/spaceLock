//
//  SLLoginViewController.swift
//  spacelab
//
//  Created by Shawn Roske on 3/24/15.
//  Copyright (c) 2015 space150, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
//  associated documentation files (the "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
//  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
//  THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import UIKit

class SLLoginViewController: UIViewController
{
    @IBOutlet weak var movieContainerView: UIView!
    @IBOutlet weak var loginButton: UIButton!
    
    fileprivate var playerViewController : VideoPlayerViewController!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        loginButton.layer.cornerRadius = 5.0
        loginButton.clipsToBounds = true
        
        // add the video for the face animation
        playerViewController = VideoPlayerViewController()
        playerViewController.playOnLoad = true
        playerViewController.loopPlayback = true
        playerViewController.url = Bundle.main.url(forResource: "startup-movie.mp4", withExtension: nil)
        playerViewController.view.frame = movieContainerView.frame
        movieContainerView.addSubview(playerViewController.view)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doLogin(_ sender: AnyObject)
    {
        let signIn = GPPSignIn.sharedInstance()!
        signIn.authenticate()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
