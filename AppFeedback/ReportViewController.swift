//
//  ReportViewController.swift
//  AppFeedback
//
//  Created by tahori on 2019/03/27.
//  Copyright © 2019 Yahoo! JAPAN Corporation. All rights reserved.
//

import Foundation
import AVFoundation
import AVKit


@objc
public protocol ReportViewControllerDelegate {
    func reportViewControllerClosed()
}

@objcMembers
public class ReportViewController : UIViewController {
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var imageView: UIImageView!
    public var image: UIImage!
    public var videoPath: URL!
    var drawnImage: UIImage!
    public var config: Config!
    public var delegate: ReportViewControllerDelegate?
    
    typealias AlertComletionBlock = (_ buttonIndex: AlertButtonIndex) ->  Void
    
    enum AlertButtonIndex : Int {
        case UIAlertCancelButtonIndex = 0
        case UIAlertDestructiveButtonIndex = 1
        case UIAlertFirstOtherButtonIndex = 2
    }
    

    // MARK: - Private properties
    
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var reporterName: UITextField!
    @IBOutlet weak var freeCommentField: UIPlaceHolderTextView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var keyboardAccessoryView: UIView!
    @IBOutlet weak var keyboardAccessoryBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var freeCommentHeightConstraint: NSLayoutConstraint!
    var keyboardHeight: CGFloat = 0
    @IBOutlet weak var activityView: UIVisualEffectView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var DrawingButton: UIButton!
    @IBOutlet weak var RecordingButton: UIButton!
    @IBOutlet weak var feedbackCategoryLabel: UILabel!
    @IBOutlet weak var sendingLabel: UILabel!
    @IBOutlet weak var feedbackCategoryButton: ExpansionButton!
    var notSelectedCategoryTitle: String = ""

    var focusOnReporterName: Bool = false
    
    
    
    // MARK: - Life cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.p_setupView();
        self.feedbackCategoryButton.setPerceivableArea(leftArea: 0.0, rightArea: 0.0)
        self.notSelectedCategoryTitle = AppFeedbackLocalizedString.string(for: "select")
    
        self.keyboardAccessoryView.isHidden = true

        if let nav = self.navigationController {
            self.setupNavBarAttributes(navController: nav)
        }
    
        // dismiss時にcallbackが呼ばれない問題の対応
        // http://stackoverflow.com/a/30069208/7642392
        self.modalPresentationStyle = .fullScreen
        self.freeCommentField.minHeight = self.freeCommentHeightConstraint.constant
        self.freeCommentField.heightConstraint = self.freeCommentHeightConstraint
    
        self.activityView.isHidden = true
        self.activityView.superview?.bringSubviewToFront(self.activityView)
    
        self.sendingLabel.text = AppFeedbackLocalizedString.string(for: "sendingLabelText")
        self.sendingLabel.isHidden = true
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // キーボード表示・非表示時のイベント登録
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChange(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHidden(notification:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)

    
        self.p_setupImageView()
        self.p_setupView()
        self.hiddenButton()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    
        // キーボード表示・非表示時のイベント削除
        NotificationCenter.default.removeObserver(self,
                                                  name: UIResponder.keyboardWillChangeFrameNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIResponder.keyboardWillHideNotification,
                                                  object: nil)
    }
    
    func p_close() {
        self.p_close(completion: {})
    }
    
    func p_close(completion: () -> Void) {
        self.closeKeyboard()
        self.drawnImage = nil

        self.dismiss(animated: true) {
            self.delegate?.reportViewControllerClosed()
        }
        completion()
    }

    func p_setupView() {
        self.container.clipsToBounds  = true
        self.freeCommentField.clipsToBounds = true
    
        self.freeCommentField.layer.cornerRadius = 5.0
    
        self.freeCommentField.placeholder = AppFeedbackLocalizedString.string(for : "comment")
        self.freeCommentField.placeholderColor = UIColor.lightGray
    
        let userDefaults = UserDefaults.standard
        if let userName = userDefaults.string(forKey: "report.user_name") {
            self.reporterName.text = userName
        }
    
        self.reporterName.delegate = self
        self.freeCommentField.delegate = self
        self.titleTextField.delegate = self
    }
    
    func p_setupImageView() {
        if let videoPath = self.videoPath {
            if let image = self.generateVideoPreviewImage(url: videoPath) {
                self.imageView.image = image
            }
            self.playButton.isHidden = false
        } else if let drawnImage = self.drawnImage {
            self.playButton.isHidden = true
            self.imageView.image = drawnImage
        } else if let image = self.image {
            self.playButton.isHidden = true
            self.imageView.image = image
        }
    }
    
    //動画保存時は「画像編集開始」ボタンを非表示・描画画像保存時は「キャプチャ開始」ボタンを非表示
    func hiddenButton() {
        if self.videoPath != nil {
            self.DrawingButton.isEnabled = false
            self.DrawingButton.alpha = 0.4
    
            self.RecordingButton.isEnabled = true
            self.RecordingButton.alpha = 1
    
        } else if self.drawnImage != nil {
            self.DrawingButton.isEnabled = true
            self.DrawingButton.alpha = 1
    
            self.RecordingButton.isEnabled = false
            self.RecordingButton.alpha = 0.4
        } else {
            self.DrawingButton.isEnabled = true
            self.DrawingButton.alpha = 1
    
            self.RecordingButton.isEnabled = true
            self.RecordingButton.alpha = 1
        }
    }
    
    func closeKeyboard() {
        self.view.endEditing(true)
    }
    
    @objc func keyboardWillChange(notification: NSNotification) {
        self.view.layoutIfNeeded()
        // キーボードの top を取得する
        
        guard let userInfo = notification.userInfo,
              var keyboardRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            NSLog("Failed to get keyboard frame")
            return
        }
        
        let origKeyboardRect = keyboardRect
        let margin: CGFloat = 4.0
    
    
        if focusOnReporterName {
            self.keyboardAccessoryView.isHidden = true
        } else {
            self.keyboardAccessoryView.isHidden = false
        }
    
        keyboardRect.size.height += self.keyboardAccessoryView.frame.size.height + margin
        keyboardRect.origin.y -= self.keyboardAccessoryView.frame.size.height - margin
        self.keyboardHeight = keyboardRect.size.height
    
        UIView.beginAnimations(nil, context:nil)

        // キーボードアニメーションと同じ間隔、速度になるように設定
        if let userInfo = notification.userInfo {
            if let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
                UIView.setAnimationDuration(duration)
            }
            if let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UIView.AnimationCurve {
                UIView.setAnimationCurve(curve)
            }
        }

        UIView.setAnimationBeginsFromCurrentState(true)
    
        self.keyboardAccessoryBottomConstraint.constant = origKeyboardRect.size.height
        self.view.layoutIfNeeded()
    
        // 表示アニメーション開始
        UIView.commitAnimations()
    
        // scrollView の contentInset と scrollIndicatorInsets の bottom に追加
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardRect.size.height, right: 0.0)
        self.scrollView.contentInset = contentInsets
        self.scrollView.scrollIndicatorInsets = contentInsets
    
        if self.freeCommentField.isFirstResponder {
            self.scrollToTextViewCaret(textView: self.freeCommentField)
        }
    }
    

    
    @objc func keyboardWillHidden(notification: NSNotification) {
        // キーボードアニメーションと同じ間隔、速度になるように設定
        UIView.beginAnimations(nil, context:nil)
        
        if let userInfo = notification.userInfo {
            if let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
                UIView.setAnimationDuration(duration)
            }
            if let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UIView.AnimationCurve {
                UIView.setAnimationCurve(curve)
            }
        }

        self.keyboardHeight = 0;
    
        // インセットを 0 にする
        let contentInsets = UIEdgeInsets.zero
        self.scrollView.contentInset = contentInsets
        self.scrollView.scrollIndicatorInsets = contentInsets
    
        self.keyboardAccessoryView.isHidden = true
        self.keyboardAccessoryBottomConstraint.constant = 0
        self.view.layoutIfNeeded()
    
        // 非表示アニメーション開始
        UIView.commitAnimations()
    }
    

    
    func p_createAlert(title: String?, message: String, cancelButtonTitle: String?, destructiveButtonTitle: String?, otherButtonTitle: String?, tapBlock: AlertComletionBlock?) {
    
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
        if let cancelButtonTitle = cancelButtonTitle {
            ac.addAction(UIAlertAction(title: cancelButtonTitle, style: .default) { action in
                tapBlock?(.UIAlertCancelButtonIndex)
            })
        }

        if let destructiveButtonTitle = destructiveButtonTitle {
            ac.addAction(UIAlertAction(title: destructiveButtonTitle, style: .default) { action in
                tapBlock?(.UIAlertDestructiveButtonIndex)
            })
        }

        if let otherButtonTitle = otherButtonTitle {
            ac.addAction(UIAlertAction(title: otherButtonTitle, style: .default) { action in
                tapBlock?(.UIAlertFirstOtherButtonIndex)
            })
        }
    
        self.present(ac, animated: true, completion: nil)
    }
    
    func p_takeScreenShot(image: UIImage) -> Data? {

        let imageData = image.pngData()
    
        return imageData
    }
    
    func p_sendMessage() {
        if let videoPath = self.videoPath {
            let videoSize = videoPath.fileSize
            let indicatorThresholdSize = 1 * 1024 * 1024

            if videoSize > indicatorThresholdSize {
                self.enableActivityIndicator(true)
            }

            self.p_sendMessage(image: nil, videoPath: videoPath)
        } else {
            self.p_sendMessage(image: self.imageView.image, videoPath: nil)
        }
    }
    
    func p_sendMessage(image: UIImage?, videoPath: URL?) {
        //ScreenShot取得
        let imageData: Data?
        if let image = image {
            imageData = self.p_takeScreenShot(image: image)
        } else {
            imageData = nil
        }
        
        let sendData = SendData(imageData: imageData,
                                videoPath: videoPath,
                                title: self.titleTextField.text,
                                category: self.feedbackCategoryButton.currentTitle,
                                comment: self.freeCommentField.text,
                                username: self.reporterName.text,
                                appTitle: (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "",
                                appVersion: DeviceUtil.appVersion,
                                appBuildVersion: DeviceUtil.appBuildVersion,
                                systemVersion: DeviceUtil.osVersion,
                                modelCode: DeviceUtil.modelCode,
                                modelName: DeviceUtil.modelName)
        
        self.sendingLabel.isHidden = false
    
        let slackAPI = SlackAPI(token: self.config.slackToken,
                                channel: self.config.slackChannel,
                                apiUrl: self.config.slackApiUrl,
                                branchName: self.config.branchName)

        slackAPI.post(data: sendData) { (data, response, error) in
            let error = error as NSError?
            self.enableActivityIndicator(false)
            self.sendingLabel.isHidden = true
    
            if let error = error {
                if error.code == CFNetworkErrors.cfurlErrorUserCancelledAuthentication.rawValue {//401(Authentication failure)
                    self.p_createAlert(title: AppFeedbackLocalizedString.string(for: "slackPostErrorTitle"),
                                       message: AppFeedbackLocalizedString.string(for: "slackPostInvalidMessage"),
                                       cancelButtonTitle:nil,
                                       destructiveButtonTitle:nil,
                                       otherButtonTitle:"OK",
                                       tapBlock:nil)
                } else {
                    self.p_createAlert(title: AppFeedbackLocalizedString.string(for:"slackPostErrorTitle"),
                                       message:AppFeedbackLocalizedString.string(for:"slackPostClientErrorMessage"),
                                       cancelButtonTitle:nil,
                                       destructiveButtonTitle:nil,
                                       otherButtonTitle:"OK",
                                       tapBlock:nil)
                }
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            switch statusCode {
            case 200:
                guard let data = data else {
                    self.p_createAlert(title: "Slack Error",
                                       message: "Invalid response",
                                       cancelButtonTitle:nil ,
                                       destructiveButtonTitle:nil ,
                                       otherButtonTitle:"OK",
                                       tapBlock:nil)
                    return
                }
                
                if !data.ok {
                    self.p_createAlert(title: "Slack Error", message: data.error ?? "Invalid response json",
                                       cancelButtonTitle:nil ,
                                       destructiveButtonTitle:nil ,
                                       otherButtonTitle:"OK" ,
                                       tapBlock:nil)
                }
                
                self.titleTextField.text = ""
                self.freeCommentField.text = ""
                self.doneSelectedFeedbackCategory(selectedCategory: self.notSelectedCategoryTitle, isSelected: false)  // 未選択の状態に戻す
    
                self.p_createAlert(title:AppFeedbackLocalizedString.string(for:"slackPostSuccessTitle"),
                                   message:AppFeedbackLocalizedString.string(for:"slackPostSuccessMessage"),
                                   cancelButtonTitle:nil,
                                   destructiveButtonTitle:nil,
                                   otherButtonTitle:"OK",
                                   tapBlock: { _ in
                                    self.p_close()
                                   })
                break
            case 403:// Forbidden
                self.p_createAlert(title:AppFeedbackLocalizedString.string(for: "slackPostErrorTitle"),
                                   message:AppFeedbackLocalizedString.string(for:"slackPostAuthorizationErrorMessage"),
                                   cancelButtonTitle:nil,
                                   destructiveButtonTitle:nil,
                                   otherButtonTitle:"OK",
                                   tapBlock:nil)
                break
    
            case 500://Internal Error
                self.p_createAlert(title:AppFeedbackLocalizedString.string(for: "slackPostErrorTitle"),
                                   message:AppFeedbackLocalizedString.string(for:"slackPostUnknownErrorMessage"),
                                   cancelButtonTitle:nil,
                                   destructiveButtonTitle:nil,
                                   otherButtonTitle:"OK",
                                   tapBlock:nil)
                break
    
            default:
                self.p_createAlert(title: AppFeedbackLocalizedString.string(for: "slackPostErrorTitle"),
                                   message:String(format: AppFeedbackLocalizedString.string(for: "slackPostUnknownErrorStatucCodeMessage"), statusCode),
                                                          cancelButtonTitle:nil,
                                                          destructiveButtonTitle:nil,
                                                          otherButtonTitle:"OK",
                                                          tapBlock:nil)
                break
            }
        }
    }
    
    func enableActivityIndicator(_ enable: Bool) {
        self.activityView.isHidden = !enable
        self.sendButton.isEnabled = !enable
    }
    

    func scrollToTextViewCaret(textView: UITextInput) {
        guard let selectedTextRange = textView.selectedTextRange else {
            return
        }
        
        guard let view = textView.textInputView else {
            return
        }

        var caretRect = textView.caretRect(for: selectedTextRange.end)

        // カーソルが最後にあると INFINITY になる……？
        if caretRect.origin.y == CGFloat.infinity {
            caretRect.origin.y = view.frame.size.height
            caretRect.origin.x = 0
            caretRect.size.height = 10
            caretRect.size.width = 1
        }
    

        
        caretRect.origin = view.convert(caretRect.origin, to: self.scrollView)
    
        let keyboardTopBorder = self.scrollView.frame.size.height - self.keyboardHeight
    
        if caretRect.origin.y + caretRect.size.height > keyboardTopBorder {
            let rect = caretRect
            self.scrollView.scrollRectToVisible(rect, animated:true)
        }
    }
    
    // MARK: - Video関連
    
    func generateVideoPreviewImage(url: URL) -> UIImage? {
        let asset: AVURLAsset = AVURLAsset(url: url, options:nil)
        let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let thumbTime = CMTimeMakeWithSeconds(0.5, preferredTimescale: Int32())
    
        do {
            let imageRef = try generator.copyCGImage(at: thumbTime, actualTime:nil)
            let image = UIImage(cgImage:imageRef,
                                scale:UIScreen.main.scale,
                                orientation:UIImage.Orientation.up)

            return image
        } catch let e {
            print(e)
            return nil
        }
    }
    
    // MARK: - IBActions
    
    @IBAction func didTapOK(_ sender: Any) {
        if (self.reporterName.text ?? "").count > 0 {
            let userDefaults = UserDefaults.standard
            userDefaults.setValue(self.reporterName.text, forKey:"report.user_name")
            userDefaults.synchronize()
        }
    
        if (self.titleTextField.text ?? "").count == 0 {
            self.p_createAlert(title: nil,
                               message:AppFeedbackLocalizedString.string(for :"confirmReportSettingInputTitleMessage"),
                               cancelButtonTitle:nil,
                               destructiveButtonTitle:nil,
                               otherButtonTitle:"OK",
                               tapBlock:  { (buttonIndex) in
                                self.titleTextField.becomeFirstResponder()
                               })
            return
        }
    
        if (self.reporterName.text ?? "").count == 0 {
            self.p_createAlert(title: AppFeedbackLocalizedString.string(for: "confirmReportSettingMessage"),
                               message:AppFeedbackLocalizedString.string(for: "confirmReportSettingSlackIdCausionMessage"),
                               cancelButtonTitle:nil,
                               destructiveButtonTitle:nil,
                               otherButtonTitle:"OK",
                               tapBlock:  { buttonIndex in
                                self.reporterName.becomeFirstResponder()
                               })
            return
        }
    
        var confirmMsg = AppFeedbackLocalizedString.string(for: "confirmReportSettingMessage")
    
        if self.feedbackCategoryButton.currentTitle == self.notSelectedCategoryTitle {
            confirmMsg = String(format: "%@\n\n%@", confirmMsg, AppFeedbackLocalizedString.string(for: "confirmReportSettingNotSelectedCategoryMessage"))
        }
    
    
        self.p_createAlert(title: AppFeedbackLocalizedString.string(for: "confirm"),
                           message:confirmMsg,
                           cancelButtonTitle:AppFeedbackLocalizedString.string(for: "cancel"),
                           destructiveButtonTitle:nil,
                           otherButtonTitle:AppFeedbackLocalizedString.string(for: "send"),
                           tapBlock:  { buttonIndex in
                            if buttonIndex == AlertButtonIndex.UIAlertFirstOtherButtonIndex {
                                self.p_sendMessage()
                                self.closeKeyboard()
                            }
                           })
    }
    
    @IBAction func didTapCancel(sender: Any) {
        self.p_close()
    }
    
    
    @IBAction func videoButtonTapped(sender: Any) {

        let message = String(format: AppFeedbackLocalizedString.string(for: "videoButtonTappedAlertMessage"), Int(floor(VIDEO_LIMIT_SECS)))
        self.p_createAlert(title: AppFeedbackLocalizedString.string(for: "videoButtonTappedAlertTitle"),
                           message:message,
                           cancelButtonTitle:AppFeedbackLocalizedString.string(for: "cancel"),
                           destructiveButtonTitle:nil,
                           otherButtonTitle:AppFeedbackLocalizedString.string(for: "videoButtonTappedAlertStartButtonTitle"),
                           tapBlock: { buttonIndex in
                            if buttonIndex ==  AlertButtonIndex.UIAlertFirstOtherButtonIndex {
                                self.p_close {
                                    AppFeedback.startRecording()
                                }
                            }
                           })
    }
    
    @IBAction func playButtonTapped(sender: Any) {
        if self.videoPath == nil {
            return
        }
    
        let avPlayer = AVPlayer(url: self.videoPath)
        let controller = AVPlayerViewController()
        controller.player = avPlayer
        self.present(controller, animated:true, completion: {
            avPlayer.play()
        })
    }
    
    @IBAction func closeKeyboardButtonTapped(sender: Any) {
        self.closeKeyboard()
    }
    
    // 描画画面に遷移する際スクリーンショットを渡す
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToDrawing" {
            let navController = segue.destination as! UINavigationController
            self.setupNavBarAttributes(navController: navController)
            let drawViewController = navController.topViewController as! DrawViewController
            if let cgImage = self.image.cgImage {
                drawViewController.originImage = UIImage(cgImage: cgImage)
            }
            if let senderImage = sender as? UIImage, let cgImage = senderImage.cgImage {
                drawViewController.editingImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    // 保存ボタンを押して描画画面から戻った時の処理
    @IBAction func unwindToDrawViewController(segue: UIStoryboardSegue) {
        let drawViewController = segue.source as! DrawViewController
        if (drawViewController.editingImage != nil) {
            drawViewController.editingImage = nil
            self.drawnImage = drawViewController.imageView.image
        } else {
            self.drawnImage = nil
            self.imageView.image = drawViewController.originImage
        }
        self.videoPath = nil
    }
    
    // 画像編集ボタンを押した時の処理
    @IBAction func editButton(sender: Any) {
        // 既に保存されている画像がある場合、途中から編集する
        if (self.drawnImage != nil) {
            self.performSegue(withIdentifier: "goToDrawing", sender: self.imageView.image)
        } else {
            self.performSegue(withIdentifier: "goToDrawing", sender: nil)
        }
    }
    
    func setupNavBarAttributes(navController: UINavigationController) {
        // storyboardからだと反映されないので、コードから直接色指定する。
        navController.navigationBar.barTintColor = UIColor(red:0.278, green:0.729, blue:0.678, alpha:1.0)
        navController.navigationBar.titleTextAttributes = [ NSAttributedString.Key.foregroundColor: UIColor.white ]
    }
    
    // フィードバックカテゴリ選択ボタンを押下した時の処理
    @IBAction func selectFeedbackCategory(sender: Any) {
        let alertController = UIAlertController(title: AppFeedbackLocalizedString.string(for: "categoryMessage"),
                                                message:nil,
                                                preferredStyle: .actionSheet)
    
        let cancelAction = UIAlertAction(title: AppFeedbackLocalizedString.string(for: "cancel"),
                                         style: .cancel,
                                         handler: { _ in })
    
        alertController.addAction(cancelAction)


        for category in self.config.categories {
            let selectAction = UIAlertAction(title:category,
                                             style: .default,
                                             handler: { action in
                                                self.doneSelectedFeedbackCategory(selectedCategory: category, isSelected: true)
                                             })
    
            if #available(iOS 13.0, *) {
                selectAction.setValue(UIColor.label, forKey: "titleTextColor")
            } else {
                selectAction.setValue(UIColor.darkGray, forKey: "titleTextColor")
            }
            
            alertController.addAction(selectAction)
        }
    
        // iPad で Action Sheet を使う場合、popoverPresentationController を設定しないとクラッシュする。
        alertController.popoverPresentationController?.sourceView = self.feedbackCategoryLabel
        alertController.popoverPresentationController?.sourceRect = self.feedbackCategoryButton.frame
    
        self.present(alertController, animated: true, completion: nil)
    }
    
    // 選択したフィードバックカテゴリを画面に反映する。
    func doneSelectedFeedbackCategory(selectedCategory: String, isSelected: Bool) {
        self.feedbackCategoryButton.setTitle(selectedCategory, for: .normal)
        self.feedbackCategoryButton.isSelected = isSelected
    }
}

extension ReportViewController: UITextFieldDelegate {

    private func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.reporterName {
            textField.resignFirstResponder()
            return true
        }
    
        if textField == self.titleTextField {
            textField.resignFirstResponder()
            self.freeCommentField.becomeFirstResponder()
            return false
        }
    
        return true
    }
    
    // reporterNameにフォーカスが当たった
    private func textFieldDidBeginEditing(_ textField: UITextField) {
        focusOnReporterName = textField == self.reporterName
    }
    
    // reporterNameからフォーカスが外れた
    private func textFieldDidEndEditing(_ textField: UITextField) {
        /*特にやることなし*/
    }
}

extension ReportViewController: UITextViewDelegate {
    // freeCommentFieldにフォーカスが当たった
    private func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        focusOnReporterName = false
        self.scrollToTextViewCaret(textView: textView)
        return true
    }
 
    private func textViewDidChange(_ textView: UITextView) {
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        self.scrollToTextViewCaret(textView: textView)
    }
    
    // freeCommentFieldからフォーカスが外れた
    private func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        /*特にやることなし*/
        return true
    }
}
