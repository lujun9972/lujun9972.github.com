(require 'package)
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  (when no-ssl (warn "\
Your version of Emacs does not support SSL connections,
which is unsafe because it allows man-in-the-middle attacks.
There are two things you can do about this warning:
1. Install an Emacs version that does support SSL and be safe.
2. Remove this warning from your init file so you won't see it again."))
  ;; Comment/uncomment these two lines to enable/disable MELPA and MELPA Stable as desired
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  ;;(add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  (when (< emacs-major-version 24)
    ;; For important compatibility libraries like cl-lib
    (add-to-list 'package-archives (cons "gnu" (concat proto "://elpa.gnu.org/packages/")))))
(package-initialize)
(package-refresh-contents)
(package-install 'mustache)
(package-install 'htmlize)
(package-install 'yaml-mode)
(package-install 'lua-mode)
(package-install 'dockerfile-mode)
(package-install 'docker-compose-mode)
(package-install 'ox-gfm)
(package-install 'request)

(setq load-path (cons  "~/EGO/" load-path))
(setq load-path (cons  "~/csdn-publish/" load-path))
(setq load-path (cons  "~/toutiao/" load-path))
(require 'log-edit)
(require 'htmlize)
(require 'ego)
(require 'toutiao)
(setq ego-project-config-alist
 `(("blog" :repository-directory "~/source" :site-domain "https://lujun9972.github.io/" :site-main-title "暗无天日" :site-sub-title "=============>DarkSun的个人博客" :theme
    (DarkSun)
    :summary
    (("years" :year :updates 15)
     ("tags" :tags))
    :source-browse-url
    ("Github" ,(getenv "REPO"))
    ;; :personal-avatar "https://avatar.csdnimg.cn/6/2/4/1_lujun9972.jpg"
    :personal-disqus-shortname "lujun9972" :personal-google-analytics-id "7bac4fd0247f69c27887e0d4e3aee41e" :ignore-file-name-regexp "README.org" :store-dir "~/web")))
(message "BEGIN TO AUTO PUBLIC")
(setq org-export-use-babel nil)
(setq org-export-with-broken-links t)
(setq debug-on-error t)
(setq org-src-fontify-natively t)
(setq org-html-htmlize-output-type 'css)
(setq safe-local-variable-values '((org-export-use-babel . t)))
(require 'ob-shell)
(require 'ox-gfm)
(require 'cl-lib)
(require 'request)
;; publish CSDN
(require 'csdn-publish)
(setq csdn-publish-open-url nil)

(defun get-origin-link (filename)
  (let* ((vc-root (file-name-as-directory (file-truename (vc-git-root filename))))
         (project (cl-find-if (lambda (project)
                                (let* ((properties (cdr project))
                                       (repository-directory (plist-get properties :repository-directory))
                                       (abs-path (file-name-as-directory (file-truename repository-directory))))
                                  (string= vc-root abs-path)))
                              ego-project-config-alist)))
    (if project
        (let* ((site-domain  "https://www.lujun9972.win")
               (ego-current-project-name (car project))
               (options (car (ego--get-org-file-options filename vc-root nil)))
               (uri (plist-get options :uri)))
          (concat (replace-regexp-in-string "/?$" ""  site-domain) uri))
      (csdn-publish-convert-link filename))))


(setq csdn-publish-original-link-getter #'get-origin-link)

(let* ((ego-current-project-name "blog")
       (repo-dir (ego--get-repository-directory))
       (base-git-commit (or (ego--get-first-commit-before-publish)
                            "HEAD~1"))
       (changed-files (ego-git-get-changed-files repo-dir base-git-commit))
       (updated-files (plist-get changed-files :update))
       (deleted-files (plist-get changed-files :delete))
       (updated-org-files (cl-delete-if-not (lambda (file)
                                              (string-suffix-p ".org" file)) updated-files))
       (publish-org-files (cl-delete-if (lambda (file)
                                          (string= (file-name-nondirectory file) "README.org"))
                                        updated-org-files)))
  (when publish-org-files
    (csdn-publish-articles publish-org-files)))
;; 设置发布到toutiao
(defun post-to-toutiao (attr-plist)
  (let ((uri (concat "https://www.lujun9972.win" (plist-get attr-plist :uri)))
        (title (plist-get attr-plist :title))
        (category  "杂说乱炖")
        (toutiao-request-sync t))
    (when (string= (plist-get attr-plist :category) "Emacs之怒")
      (setq category "Emacs之怒"))
    (when (string= (plist-get attr-plist :category)  "英文必须死")
      (setq category "有趣即是正义"))
    (message "toutiao DEBUG[%s][%s][%s]" uri title category)
    (toutiao-post uri title category)))
(add-hook 'ego-post-publish-hooks #'post-to-toutiao)

;; publish ego log
(ego-do-publication "blog" nil nil nil)
