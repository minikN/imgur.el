;;; imgur.el --- imgur interface -*- lexical-binding: t -*-
;; Copyright (C) 2016 Lars Magne Ingebrigtsen

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;; Keywords: fun

;; imgur.el is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; imgur.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;; Code:

(require 'cl)
(require 'json)
(require 'mm-url)

;;;###autoload
(defconst imgur-client-id "7a3bd475cd9f48c"
  "This is the imgur client ID for the imgur.el library.
It can only be used for anonymous uploads.")

;;;###autoload
(defconst ext "png"
  "The default extension used for saving screenshots.")

;;;###autoload
(defun imgur-init-screenshot ()
  "Initiate the process of taking a screenshot."
  (interactive "Take a screenshot")
  (let* ((sizes '("Section" "Full Screen"))
         (targets '("Imgur" "Locally")))
  (setq size (completing-read "Take Screenshot of ..." sizes)
        target (completing-read "Save Screenshot to ..." targets))
  (sit-for 0)
  (cond ((equal target "Imgur")
         (if (equal size "Section")
             (imgur-screenshot nil)
           (imgur-screenshot t)))
        ((equal target "Locally")
         (if (equal size "Section")
             (imgur-screenshot-save nil)
           (imgur-screenshot-save t))))))

;;;###autoload
(defun imgur-upload-image (image &optional datap kill)
  "Upload IMAGE to imgur and return the resulting imgur URL.
If called interactively, copy the resulting URL to the kill ring.

If DATAP in non-nil, IMAGE should be a binary string containing
the image.  If not, it should be a file name.

If KILL, copy the resulting url to the kill ring."
  (interactive "Image to upload to imgur: ")
  (let* ((image (if datap
		    image
		  (with-temp-buffer
		    (set-buffer-multibyte nil)
		    (insert-file-contents image)
		    (buffer-string))))
	 (url-request-method "POST")
	 (url-request-extra-headers
	  `(("Content-Type" . "application/x-www-form-urlencoded")
	    ("Authorization" . ,(concat "Client-ID " imgur-client-id))))
	 (url-request-data
	  (mm-url-encode-www-form-urlencoded
	   `(("image" . ,(with-temp-buffer
			   (set-buffer-multibyte nil)
			   (insert image)
			   (base64-encode-region (point-min) (point-max))
			   (buffer-string))))))
	 (result (url-retrieve-synchronously
		  "https://api.imgur.com/3/image.json"))
	 json)
    (unless result
      (error "No response from imgur"))
    (with-current-buffer result
      (goto-char (point-min))
      (when (re-search-forward "\n\n" nil t)
	(setq json (json-read)))
      (kill-buffer (current-buffer)))
    (let ((url (cdr (assq 'link (car json)))))
      (when (or (called-interactively-p 'interactive)
		kill)
	(message "Copied '%s' to the kill ring" url)
	(with-temp-buffer
	  (insert (url-encode-url url))
	  (copy-region-as-kill (point-min) (point-max))))
      url)))

;;;###autoload
(defun imgur-screenshot (full-screen)
  "Take a screenshot and upload to imgur."
  (interactive "p")
  (unless (executable-find "import")
    (error "Can't find the ImageMagick import command on this system"))
  (imgur-upload-image
   (with-temp-buffer
     (set-buffer-multibyte nil)
     (if full-screen
         (call-process "import" nil (current-buffer) nil "-window" "root" "png:-")
       (call-process "import" nil (current-buffer) nil "png:-"))
     (buffer-string))
   t t))

;;;###autoload
(defun imgur-screenshot-save (full-screen)
  "Take a screenshot and save to a file."
  (interactive "P")
  (unless (executable-find "import")
    (error "Can't find the ImageMagick import command on this system"))
  (let ((file (concat
               (read-directory-name "Select directory: " "~/")
               (read-string "File name (Without extension): ") "." ext)))
    (sit-for 0)
    (if full-screen
        (call-process "import" nil (current-buffer) nil "-window" "root" file)
      (call-process "import" nil (current-buffer) nil file))
    (kill-new file)
    (message "Copied %s" file)))

(provide 'imgur)
;;; imgur.el ends here
