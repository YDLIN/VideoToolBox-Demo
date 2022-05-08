//
//  ViewController.swift
//  01 - EncodeH264
//
//  Created by Du on 2022/5/6.
//

import UIKit
import AVFoundation
import VideoToolbox
import SnapKit

private let KMainCellIdentifier = "KMainCellIdentifier"

class ViewController: UIViewController {
    lazy var tableView: UITableView = setupTableView()
    
    lazy var demoList = ["Video Capture"]
    lazy var demoPageNameList = ["VideoCaptureViewController"]

    override func viewDidLoad() {
        super.viewDidLoad()
        /// 初始化
        setupUI()
    }
    
    private func setupUI() {
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        
        title = "Demos"
        
        view.backgroundColor = .white
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
    }
    
    private func junpToVc(name: String) {
        //1.获取命名空间
       guard let nameSpace = Bundle.main.infoDictionary!["CFBundleName"] as? String else{
           print("没有获取到命名空间")
           return
       }
       //2.根据字符串获取对应的Class
       guard let childVCClass = NSClassFromString(nameSpace + "." + name) else {
           print("没有获取到字符串对应的Class")
           return
       }
       //3.将对应的AnyObject转成控制器类型
       guard let childType = childVCClass as? UIViewController.Type else{
           print("没有获取对应控制器的类型")
           return;
       }
        
        let vc = childType.init()
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension ViewController {
    private func setupTableView() -> UITableView {
        let tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    // MARK:- DataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Demos"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return demoList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: KMainCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: KMainCellIdentifier)
        }
        
        if indexPath.row < self.demoList.count {
            cell?.textLabel?.text = self.demoList[indexPath.row]
        }
        return cell!
    }
    
    // MARK:- Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < self.demoPageNameList.count {
            junpToVc(name: self.demoPageNameList[indexPath.row])
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0;
    }
}

